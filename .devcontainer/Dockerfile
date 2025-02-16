FROM mcr.microsoft.com/devcontainers/ruby:3.3

# Install Rails
# RUN su vscode -c "gem install rails webdrivers"
RUN su vscode -c "/usr/local/rvm/bin/rvm fix-permissions"

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    git \
    build-base \
    mysql-dev \
    nodejs \
    yarn \
    tzdata \
    && gem update --system

# [Optional] Uncomment this line to install additional gems.
RUN su vscode -c "gem install foreman"

# RUN su vscode -c "bin/setup"

# [Optional] Uncomment this line to install global node packages.
# RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g <your-package-here>" 2>&1
