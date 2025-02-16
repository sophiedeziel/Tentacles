FROM mcr.microsoft.com/devcontainers/ruby:3.3

# Install Rails
# RUN su vscode -c "gem install rails webdrivers"
RUN su vscode -c "/usr/local/rvm/bin/rvm fix-permissions"

# Default value to allow debug server to serve content over GitHub Codespace's port forwarding service
# The value is a comma-separated list of allowed domains
ENV RAILS_DEVELOPMENT_HOSTS=".githubpreview.dev,.preview.app.github.dev,.app.github.dev"
ENV PORT=5000
ENV REDIS_URL="redis://redis:6379/1"

# RUN apt-get update && apt-get -y install --no-install-recommends nodejs yarn

# install asdf
# RUN \
#     # configure git to get rid of detached head warnings
#     git config --global advice.detachedHead false; \
#     git clone https://github.com/asdf-vm/asdf.git vscode/.asdf --branch v0.10.2; \
#     /bin/bash -c 'echo -e "\n\n## Configure ASDF \n. vscode/.asdf/asdf.sh" >> ~/.bashrc'; \
#     /bin/bash -c 'echo -e "\n\n## ASDF Bash Completion: \n. vscode/.asdf/completions/asdf.bash" >> ~/.bashrc'; \
#     exec bash; \
# # install asdf-ruby
#     /bin/bash -c asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git; \
# # install asdf-nodejs
#     /bin/bash -c asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git;

# install asdf to manage all the thingz!!!
# RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.1 && \
#     echo ". $HOME/.asdf/asdf.sh" >> /root/.bashrc && \
#     echo ". $HOME/.asdf/asdf.sh" >> /root/.zshrc


# RUN source $HOME/.bashrc
# # install plugins
# RUN asdf plugin add nodejs


# RUN asdf install nodejs

# COPY Gemfile Gemfile.lock .tool-versions ./


# # RUN su vscode -c "source ~/.bashrc"
# # RUN su vscode -c "asdf install nodejs"
# RUN su vscode -c "bundle install"
# RUN su vscode -c "gem install foreman"

ENV DB_HOST=db
ENV DB_PASSWORD="tentacles_dev"

# [Optional] Uncomment this line to install global node packages.
# RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g <your-package-here>" 2>&1

# CMD ["bin/docker-run.sh"]
