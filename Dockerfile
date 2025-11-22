FROM ruby:3.4.6-alpine AS build-env

ARG RAILS_ROOT=/usr/src/app

ENV BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"
ENV RUBY_YJIT_ENABLE=1

RUN apk add --update --no-cache \
  git \
  build-base \
  mysql-dev \
  nodejs \
  yarn \
  tzdata \
  yaml-dev \
  && rm -rf /var/cache/apk/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*\
  && gem update --system

WORKDIR $RAILS_ROOT

COPY package.json yarn.lock ./
RUN yarn install --pure-lockfile && yarn cache clean

COPY Gemfile Gemfile.lock ./
RUN bundle config --global frozen 1 \
  && bundle config set --local path 'vendor/bundle' \
  && bundle config --local without 'development test' \
  && bundle install --jobs 1 --retry 3

RUN bundle clean --force \
  && rm -rf /usr/local/bundle/cache \
  && find vendor/bundle -name "*.c" -delete \
  && find vendor/bundle -name "*.o" -delete

COPY . .

ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
ENV SECRET_KEY_BASE="precompile_placeholder"

RUN bin/shakapacker \
  && yarn cache clean \
  && rm -rf node_modules tmp/cache/* /tmp/* yarn.lock app/ui/* spec/*

FROM ruby:3.4.6-alpine

ARG RAILS_ROOT=/usr/src/app

ENV RAILS_ENV=production
ENV NODE_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
ENV RAILS_LOG_TO_STDOUT=true
ENV BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"
ENV RUBY_YJIT_ENABLE=1

WORKDIR $RAILS_ROOT

RUN apk add --update --no-cache \
  python3 \
  mysql-dev \
  nodejs \
  vips-dev \
  nmap \
  tzdata \
  yaml-dev \
  && rm -rf /var/cache/apk/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=build-env $RAILS_ROOT $RAILS_ROOT

RUN gem install foreman

# Add a script to be executed every time the container starts.
EXPOSE 8030

# Configure the main process to run when running the image
CMD ["bin/docker-run.sh"]
