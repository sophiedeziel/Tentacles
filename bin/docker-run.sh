#!/bin/sh

export SECRET_KEY_BASE=`bundle exec rails secret`
if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi
rails db:create db:migrate
foreman start -f Procfile.prod
