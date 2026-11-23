# typed: true
# frozen_string_literal: true

# Base of the models that aren't database tables: commands (Printer::Removal), records kept in Redis
# (Printer::Status) and objects that talk to a printer. They speak ActiveRecord's vocabulary, so they read like the
# rest of app/models:
#
#   class Printer::Removal < ApplicationModel
#     attribute :printer
#     validates :printer, presence: true
#
#     private
#
#     def persist
#       printer.destroy!
#       forget_redis_keys
#       stop_spool
#     end
#   end
#
#   Printer::Removal.new(printer:).save   # => false, with `errors`, when it's invalid or an expected error occurs
#   Printer::Removal.new(printer:).save!  # raises instead
#
# - Attributes use ActiveModel::Attributes (`attribute :interval, :float, default: 5.0`).
# - Validations use ActiveModel::Validations (`validates`, `validate`).
# - No callbacks: #persist runs every step of the save, in order, inline (the write, then its follow-ups: pushes,
#   spooler notifications, cleanup). A best-effort follow-up rescues and logs its own errors.
# - `save!` validates, then runs #persist. It raises ActiveModel::ValidationError when invalid, ReadOnlyRecord on a
#   read-only model, and lets #persist's errors through.
# - `save` returns false instead of raising for its own validation errors and for the errors declared with
#   `rescue_into_errors`, whose message is added to `errors[:base]`. Unexpected errors still raise, the
#   ActiveModel::ValidationError of another model's `save!` in #persist included. A model words
#   those messages by overriding the private #error_message_for (e.g. to redact a secret); it defaults to the
#   error's message.
# - Reads use ActiveRecord's names too: `.find`, `.find_by`, `.where`, `.last`, `.exists?`, `#reload`.
class ApplicationModel
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Raised when saving a model whose #readonly? is true
  class ReadOnlyRecord < StandardError; end

  class_attribute :expected_errors, instance_writer: false, default: [].freeze

  class << self
    # Like ActiveRecord's: an abstract model (`self.abstract_class = true`, next to its `# @abstract` RBS comment)
    # is only built through its subclasses. The flag isn't inherited.
    #: bool?
    attr_writer :abstract_class

    #: -> bool
    def abstract_class?
      @abstract_class == true
    end

    # Errors #save turns into `errors[:base]` (and a false return) instead of raising. Subclasses add to their
    # parent's list.
    #: (*singleton(StandardError) error_classes) -> void
    def rescue_into_errors(*error_classes)
      self.expected_errors = (expected_errors + error_classes).freeze
    end

    #: (**untyped attributes) -> instance
    def create(**attributes)
      new(**attributes).tap(&:save)
    end

    #: (**untyped attributes) -> instance
    def create!(**attributes)
      new(**attributes).tap(&:save!)
    end
  end

  #: (*untyped, **untyped) -> void
  def initialize(*, **)
    if self.class.abstract_class?
      raise NotImplementedError,
            "#{self.class.name} is an abstract class and cannot be instantiated"
    end

    super
  end

  #: -> bool
  def save
    save!
  rescue ActiveModel::ValidationError => e
    # Another model's, from a save! in #persist: a bug, like any other error
    raise unless e.model.equal?(self)

    false
  rescue *expected_errors => e
    errors.add(:base, error_message_for(e))
    false
  end

  #: -> bool
  def save! # rubocop:disable Naming/PredicateMethod -- returns true like ActiveRecord#save!
    raise ReadOnlyRecord, "#{self.class.name} is read-only" if readonly?

    validate!
    persist
    true
  end

  #: (Hash[(String | Symbol), untyped] attributes) -> bool
  def update(attributes)
    assign_attributes(attributes)
    save
  end

  #: (Hash[(String | Symbol), untyped] attributes) -> bool
  def update!(attributes)
    assign_attributes(attributes)
    save!
  end

  #: -> bool
  def readonly?
    false
  end

  private

  # What saving means for this model: the database write, the HTTP call, the Redis write..., then its follow-up
  # steps, in order
  #: -> void
  def persist
    raise NotImplementedError, "#{self.class.name} has nothing to save"
  end

  # The message #save adds to `errors[:base]` for one of the errors declared with `rescue_into_errors`
  #: (Exception error) -> String
  def error_message_for(error)
    error.message
  end
end
