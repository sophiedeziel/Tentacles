# typed: true
# frozen_string_literal: true

# Base of the models that aren't database tables: commands (Printer::Removal), records kept in Redis
# (Printer::Status) and objects that talk to a printer. They speak ActiveRecord's vocabulary, so they read like the
# rest of app/models:
#
#   class Printer::Removal < ApplicationModel
#     attribute :printer
#     validates :printer, presence: true
#     after_save :forget_redis_keys
#
#     private
#
#     def persist = printer.destroy!
#   end
#
#   Printer::Removal.new(printer:).save   # => false, with `errors`, when it's invalid or an expected error occurs
#   Printer::Removal.new(printer:).save!  # raises instead
#
# - Attributes use ActiveModel::Attributes (`attribute :interval, :float, default: 5.0`).
# - Validations use ActiveModel::Validations (`validates`, `validate`).
# - `save!` validates, then runs #persist (the side effect) inside the save callbacks. It raises
#   ActiveModel::ValidationError when invalid, ReadOnlyRecord on a read-only model, and lets #persist's errors through.
# - `save` returns false instead of raising for validation errors and for the errors declared with
#   `rescue_into_errors`, whose message is added to `errors[:base]`. Unexpected errors still raise. A model words
#   those messages by overriding the private #error_message_for (e.g. to redact a secret); it defaults to the
#   error's message.
# - Reads use ActiveRecord's names too: `.find`, `.find_by`, `.where`, `.last`, `.exists?`, `#reload`.
class ApplicationModel
  extend T::Sig
  include ActiveModel::Model
  include ActiveModel::Attributes
  extend ActiveModel::Callbacks

  # Raised when saving a model whose #readonly? is true
  class ReadOnlyRecord < StandardError; end

  define_model_callbacks :save

  class_attribute :expected_errors, instance_writer: false, default: [].freeze

  class << self
    extend T::Sig

    # Errors #save turns into `errors[:base]` (and a false return) instead of raising. Subclasses add to their
    # parent's list.
    sig { params(error_classes: T.class_of(StandardError)).void }
    def rescue_into_errors(*error_classes)
      self.expected_errors = (expected_errors + error_classes).freeze
    end

    sig { params(attributes: T.untyped).returns(T.attached_class) }
    def create(**attributes)
      new(**attributes).tap(&:save)
    end

    sig { params(attributes: T.untyped).returns(T.attached_class) }
    def create!(**attributes)
      new(**attributes).tap(&:save!)
    end
  end

  sig { returns(T::Boolean) }
  def save
    save!
  rescue ActiveModel::ValidationError
    false
  rescue *expected_errors => e
    errors.add(:base, error_message_for(e))
    false
  end

  sig { returns(T::Boolean) }
  def save! # rubocop:disable Naming/PredicateMethod -- returns true like ActiveRecord#save!
    raise ReadOnlyRecord, "#{self.class.name} is read-only" if readonly?

    validate!
    # Returns true: ActiveModel skips the after_save callbacks when the block returns false
    run_callbacks(:save) do
      persist
      true
    end
    true
  end

  sig { params(attributes: T::Hash[T.any(String, Symbol), T.untyped]).returns(T::Boolean) }
  def update(attributes)
    assign_attributes(attributes)
    save
  end

  sig { params(attributes: T::Hash[T.any(String, Symbol), T.untyped]).returns(T::Boolean) }
  def update!(attributes)
    assign_attributes(attributes)
    save!
  end

  sig { returns(T::Boolean) }
  def readonly?
    false
  end

  private

  # What saving means for this model: the database write, the HTTP call, the Redis write...
  sig { void }
  def persist
    raise NotImplementedError, "#{self.class.name} has nothing to save"
  end

  # The message #save adds to `errors[:base]` for one of the errors declared with `rescue_into_errors`
  sig { params(error: Exception).returns(String) }
  def error_message_for(error)
    error.message
  end
end
