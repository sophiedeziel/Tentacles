
FROM ruby:3.1.2 AS tentacles

RUN apt-get update -qq && apt-get install -yq --no-install-recommends \
    build-essential \
    gnupg2 \
    less \
    git \
    libpq-dev \
    default-mysql-client \
    libvips \
    npm \
    curl \
    nmap \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sL https://deb.nodesource.com/setup_18.x  | bash -
RUN apt-get -y install nodejs

ENV LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3

ENV RAILS_ENV production
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true

# Install rails
RUN gem update --system && gem install bundler
RUN gem install rails bundler foreman
RUN npm install -g yarn

WORKDIR /usr/src/app

COPY package.json yarn.lock Gemfile Gemfile.lock ./
RUN yarn install --check-files
RUN bundle install

COPY . .

RUN rails assets:precompile SECRET_KEY_BASE="precompile_placeholder"

# Add a script to be executed every time the container starts.
EXPOSE 9000 3035 5100

# Configure the main process to run when running the image
CMD rails db:create db:migrate; rm tmp/pids/server.pid; foreman start
