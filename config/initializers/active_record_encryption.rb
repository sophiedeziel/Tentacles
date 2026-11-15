# frozen_string_literal: true

# Active Record encryption keys (used by `encrypts`, e.g. Printer#secret).
#
# This app has no credentials file, so the keys are derived from SECRET_KEY_BASE: self-hosted installs need no new
# environment variable. Each key can be set explicitly with its ACTIVE_RECORD_ENCRYPTION_* variable instead.
#
# Rotating SECRET_KEY_BASE without setting these variables to the previous keys makes the stored secrets unreadable.
#
# In development and test, every checkout has its own tmp/local_secret.txt but they may share a database (e.g. one
# Conductor workspace per branch): their keys are derived from a fixed value instead, as their data isn't sensitive.
Rails.application.config.active_record.encryption.tap do |encryption|
  # Pinned, so that bumping `load_defaults` (SHA1 before 7.1) never changes the keys of the stored secrets
  encryption.hash_digest_class = OpenSSL::Digest::SHA256
  encryption.support_sha1_for_non_deterministic_encryption = false

  base = Rails.env.local? ? 'Tentacles development and test' : Rails.application.secret_key_base
  key_generator = ActiveSupport::KeyGenerator.new(base, hash_digest_class: OpenSSL::Digest::SHA256)
  derive = ->(salt) { key_generator.generate_key("active_record_encryption #{salt}", 32).unpack1('H*') }

  encryption.primary_key = ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'].presence || derive.call('primary key')
  encryption.deterministic_key = ENV['ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY'].presence ||
                                 derive.call('deterministic key')
  encryption.key_derivation_salt = ENV['ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT'].presence ||
                                   derive.call('key derivation salt')
end
