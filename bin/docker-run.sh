#!/bin/sh

# The printers' secrets are encrypted with keys derived from SECRET_KEY_BASE (see
# config/initializers/active_record_encryption.rb), so it must not change between restarts. When none is given, one
# is generated once and kept in storage/, next to the uploaded files.
if [ -z "$SECRET_KEY_BASE" ]; then
  if [ ! -s storage/secret_key_base ]; then
    mkdir -p storage
    (umask 077 && bundle exec rails secret > storage/secret_key_base)
  fi
  SECRET_KEY_BASE=`cat storage/secret_key_base`
  export SECRET_KEY_BASE
fi
if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi
bin/rails db:create db:migrate
foreman start -f Procfile.prod
