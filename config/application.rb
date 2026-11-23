# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require 'action_text/engine'
require 'action_view/railtie'
require 'action_cable/engine'
require 'sprockets/railtie'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Tentacles
  # Linked git worktrees (e.g. Conductor workspaces) get their own databases and
  # ActionCable channels, suffixed with the worktree folder name, so checkouts
  # running in parallel never share data. The main checkout and CI (where .git
  # is a directory) keep the plain names. Override with DB_SUFFIX ("" opts out).
  WORKTREE_SUFFIX = ENV.fetch('DB_SUFFIX') do
    root = File.expand_path('..', __dir__)
    File.file?(File.join(root, '.git')) ? "_#{File.basename(root).downcase.gsub(/[^a-z0-9]+/, '_')}" : ''
  end

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.railties_order = [ActiveStorage::Engine, :main_app, :all]

    config.active_job.queue_adapter = :sidekiq

    # The global print queue (#2934), off unless GLOBAL_PRINT_QUEUE is "true" or "1". Read through PrintQueue.enabled?
    config.x.global_print_queue = %w[true 1].include?(ENV.fetch('GLOBAL_PRINT_QUEUE', '').strip.downcase)
  end
end
