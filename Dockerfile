FROM ruby:3.2.2-alpine

ENV RAILS_ENV production
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true

RUN apk add --update --no-cache \
  git \
  build-base \
  mysql-dev \
  nodejs \
  yarn \
  vips-dev \
  nmap \
  tzdata \
  && rm -rf /var/cache/apk/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*\
  && gem update --system

WORKDIR /usr/src/app

COPY package.json yarn.lock ./
RUN yarn install --pure-lockfile && yarn cache clean

COPY Gemfile Gemfile.lock ./
RUN bundle update --bundler \
  && bundle config --local without 'development test' \
  && bundle install --jobs 4 --retry 3 \
  && bundle clean --force \
  && rm -rf /usr/local/bundle/cache

COPY . .

RUN  SECRET_KEY_BASE="precompile_placeholder" bin/shakapacker\
  && yarn cache clean \
  && rm -rf node_modules tmp/cache/* /tmp/* yarn.lock log/production.log app/ui/* spec

RUN gem install foreman

# Add a script to be executed every time the container starts.
EXPOSE 8030

# Configure the main process to run when running the image
CMD rails db:create db:migrate; rm tmp/pids/server.pid; foreman start -f Procfile.prod
