# typed: true
# frozen_string_literal: true

class Printer
  # `printers.secret` (the OctoPrint API key, or the backend's password), encrypted.
  #
  # When the stored secret can't be decrypted (e.g. SECRET_KEY_BASE changed), reading it raises
  # PrinterBackends::UnreadableCredentials instead of an Active Record error: the adapters, the monitor and the
  # actions treat it like missing credentials, for this printer only. The printer can still be validated and saved,
  # and its credentials entered again.
  module EncryptedSecret
    extend T::Sig
    extend T::Helpers
    extend ActiveSupport::Concern

    included do
      T.bind(self, T.class_of(Printer))

      encrypts :secret

      before_save :forget_unreadable_secret
    end

    def secret
      super
    rescue ActiveRecord::Encryption::Errors::Decryption
      Kernel.raise PrinterBackends::UnreadableCredentials, PrinterBackends::UnreadableCredentials::MESSAGE
    end

    # The secret, or nil when it can't be decrypted
    sig { returns(T.nilable(String)) }
    def readable_secret
      secret
    rescue PrinterBackends::UnreadableCredentials
      nil
    end

    # `encrypts` validates the secret's length: a printer whose secret can't be decrypted must stay valid
    def read_attribute_for_validation(attribute)
      attribute.to_s == 'secret' ? readable_secret : super
    end

    private

    # Saving compares every attribute with its stored value, which decrypts the secret. When it can't be decrypted,
    # the stored value is forgotten so that the printer can still be saved: its secret stays as it is in the
    # database, or is replaced when a new one was assigned (the credentials are entered again).
    sig { void }
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
