# frozen_string_literal: true

# Stores a secret encrypted with other keys, like after SECRET_KEY_BASE changed, and returns the reloaded printer
module UnreadableSecret
  def make_secret_unreadable(printer)
    key_provider = ActiveRecord::Encryption::DerivedSecretKeyProvider.new('another secret key base')
    ciphertext = ActiveRecord::Encryption::Encryptor.new.encrypt('A8DDB1359AAB', key_provider:)
    connection = ActiveRecord::Base.connection
    connection.execute("UPDATE printers SET secret = #{connection.quote(ciphertext)} WHERE id = #{printer.id}")
    Printer.find(printer.id)
  end
end
