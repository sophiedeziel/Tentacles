# typed: true
# frozen_string_literal: true

class Printer
  # `printers.secret` (the OctoPrint API key, or the backend's password), encrypted.
  #
  # When the stored secret can't be decrypted (e.g. SECRET_KEY_BASE changed), reading it raises
  # Printer::Backend::UnreadableCredentials instead of an Active Record error: the adapters, the monitor and the
  # actions treat it like missing credentials, for this printer only. The printer can still be validated and saved,
  # and its credentials entered again.
  module EncryptedSecret
    extend ActiveSupport::Concern

    included do
      #: self as singleton(Printer)

      encrypts :secret
    end

    # Saving compares every attribute with its stored value, which decrypts the secret: an unreadable one is forgotten
    # first (see #forget_unreadable_secret). Every save goes through #save or #save!: update, update!, create, create!,
    # update_attribute, toggle! and autosaved associations too.
    def save(**, &)
      forget_unreadable_secret
      super
    end

    def save!(**, &)
      forget_unreadable_secret
      super
    end

    def secret
      super
    rescue ActiveRecord::Encryption::Errors::Decryption
      Kernel.raise Printer::Backend::UnreadableCredentials, Printer::Backend::UnreadableCredentials::MESSAGE
    end

    # The secret, or nil when it can't be decrypted
    #: -> String?
    def readable_secret
      secret
    rescue Printer::Backend::UnreadableCredentials
      nil
    end

    # `encrypts` validates the secret's length: a printer whose secret can't be decrypted must stay valid
    def read_attribute_for_validation(attribute)
      attribute.to_s == 'secret' ? readable_secret : super
    end

    private

    # When the stored secret can't be decrypted, its stored value is forgotten so that the printer can still be saved:
    # its secret stays as it is in the database, or is replaced when a new one was assigned (the credentials are
    # entered again).
    #: -> void
    def forget_unreadable_secret
      T.bind(self, Printer).attribute_in_database(:secret)
    rescue ActiveRecord::Encryption::Errors::Decryption
      assigned = @attributes['secret']
      new_secret = assigned.came_from_user? ? assigned.value : nil
      @attributes.write_from_database('secret', nil)
      T.bind(self, Printer).secret = new_secret unless new_secret.nil?
    end
  end
end
