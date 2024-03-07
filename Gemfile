# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '~> 3.2'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
rails_version = '~> 7.0'
gem 'actionpack',    rails_version
gem 'actionview',    rails_version
gem 'activemodel',   rails_version
gem 'activerecord',  rails_version
gem 'activesupport', rails_version
# gem "actionmailer",  rails_version
gem 'actioncable',   rails_version
gem 'activejob',     rails_version
gem 'activestorage', rails_version
# gem "actionmailbox", rails_version
# gem 'actiontext',    rails_version
gem 'railties',      rails_version

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

# Use sqlite3 as the database for Active Record
# gem "sqlite3", "~> 1.4"

gem 'mysql2', '~> 0.5.6'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 6.4'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
# gem 'importmap-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem 'jbuilder'

# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 5.1'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Sass to process CSS
# gem "sassc-rails"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

gem 'apollo_upload_server'
gem 'graphql'
gem 'octoprint', github: 'sophiedeziel/octoprint', branch: 'main' # For prototype purposes

gem 'bindex' # shakapacker won't work without this
gem 'mini_racer', platforms: :ruby
gem 'react_on_rails', '~> 13.4.0'
gem 'shakapacker', '~> 7.2'

gem 'colorize'
gem 'pry' # TODO: fix octoprint gem to not require pry
gem 'sidekiq', '~> 7.2'

gem 'listen', '~> 3.9'

group :development, :test do
  gem 'bundler-audit'
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'graphiql-rails'
  gem 'rspec-its'
  gem 'rspec-rails'
  gem 'rubocop', '~> 1.62', require: false
  gem 'rubocop-rails', '~> 2.24', require: false
  gem 'rubocop-rspec', require: false
  gem 'simplecov', require: false
  gem 'vcr', '~> 6.2'
  gem 'webmock'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'mock_redis'
  gem 'selenium-webdriver'
  gem 'webdrivers'
end
