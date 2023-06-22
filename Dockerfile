
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
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN curl -sL https://deb.nodesource.com/setup_18.x  | bash -
RUN apt-get -y install nodejs

ENV LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3

# Install rails
RUN gem update --system && gem install bundler
RUN gem install rails bundler foreman
RUN npm install -g yarn

WORKDIR /usr/src/app

#RUN chown -R user:user /opt/app



# Run a shell
# CMD ["/bin/sh"]

COPY package.json yarn.lock ./
ENV YARN_CACHE_FOLDER=/usr/local/yarn-cache
VOLUME /usr/local/yarn-cache
RUN yarn config set cache-folder $YARN_CACHE_FOLDER
RUN yarn install --check-files

COPY Gemfile Gemfile.lock ./
ENV BUNDLE_CACHE_PATH=/usr/local/bundle-cache
VOLUME /usr/local/bundle-cache
RUN bundle install

COPY . .

# Add a script to be executed every time the container starts.
EXPOSE 9000 3035 5100

# Configure the main process to run when running the image
CMD ["rails", "db:create", "db:migrate", "&&", "foreman", "start"]
