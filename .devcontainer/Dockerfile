FROM mcr.microsoft.com/devcontainers/ruby:3.3

# Install Rails
RUN su vscode -c "gem install rails webdrivers"
RUN su vscode -c "/usr/local/rvm/bin/rvm fix-permissions"

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends nodejs yarn tzdata

# RUN asdf install nodejs

COPY Gemfile Gemfile.lock ./

RUN su vscode -c "bundle install"
RUN su vscode -c "gem install foreman"

ENV DB_HOST=db
ENV DB_PASSWORD="tentacles_dev"

# [Optional] Uncomment this line to install global node packages.
# RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g <your-package-here>" 2>&1

# CMD ["bin/docker-run.sh"]
