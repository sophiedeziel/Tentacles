# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '~> 3.4'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.0'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

# Use sqlite3 as the database for Active Record
# gem "sqlite3", "~> 1.4"

gem 'mysql2', '~> 0.5.6'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 6.6'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
# gem 'importmap-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem 'jbuilder'

# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 5.4'

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
gem 'react_on_rails', '~> 14.2.1'
gem 'shakapacker', '~> 8.3'

gem 'colorize'
gem 'pry' # TODO: fix octoprint gem to not require pry
gem 'sidekiq', '~> 7.3'

gem 'listen', '~> 3.9'
gem 'sorbet-static-and-runtime', '~> 0.5.12219'

group :development, :test do
  gem 'bundler-audit'
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw x64_mingw]
  gem 'factory_bot_rails'
  gem 'graphiql-rails'
  gem 'rspec', '~> 3.13.1'
  gem 'rspec-its'
  gem 'rspec-rails'
  gem 'rubocop', '~> 1.77', require: false
  gem 'rubocop-rails', '~> 2.32', require: false
  gem 'rubocop-rspec', require: false
  gem 'simplecov', require: false
  gem 'tapioca', '~> 0.17.5', require: false
  gem 'vcr', '~> 6.3'
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
