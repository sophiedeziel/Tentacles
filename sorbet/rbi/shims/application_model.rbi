# typed: true

# The class methods that `define_model_callbacks :save` (ActiveModel::Callbacks) defines at runtime in
# app/models/application_model.rb, which Sorbet can't see
class ApplicationModel
  class << self
    sig { params(args: T.untyped, options: T.untyped, block: T.untyped).void }
    def before_save(*args, **options, &block); end

    sig { params(args: T.untyped, options: T.untyped, block: T.untyped).void }
    def around_save(*args, **options, &block); end

    sig { params(args: T.untyped, options: T.untyped, block: T.untyped).void }
    def after_save(*args, **options, &block); end
  end
end
