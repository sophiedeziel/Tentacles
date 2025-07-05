# typed: true
# frozen_string_literal: true

class Printer < ApplicationRecord
  extend T::Sig

  has_many :jobs, class_name: 'Printer::Job', dependent: :nullify

  validates :name, presence: true

  def current_job
    jobs.find_by(status: 'active') || using_api do
      data = Octoprint::Job.get
      {
        name: data.information.file[:name],
        progress: data.progress.completion.round(1)
      }
    end
  rescue StandardError
    nil
  end

  def self.table_name_prefix
    return '' if self == Printer

    'printer_'
  end

  def octoprint_version
    using_api(cache: 2.hours) do
      Octoprint::ServerVersion.get
    end
  end

  def job_status
    using_api do
      Octoprint::Job.get.state
    end
  end

  def jobs_count
    jobs.where(status: 'enqueued').count
  end

  sig { params(file: String, options: T.untyped).returns(Octoprint::Files::OperationResult) }
  def upload(file, options: {})
    using_api do
      Octoprint::Files.upload(file, **options)
    end
  end

  def using_api(cache: false, &)
    method = T.must(T.must(caller[0])[/'.*'/])[1..-2]
    OctoprintCache.use_cache(id:, method:, time: cache) do
      api_client.use(&)
    end
  rescue Faraday::ConnectionFailed => e
    Rails.logger.error("Failed to get OctoPrint data for #{name} :\n\t#{e.message}")
    OctoprintCache.set_disconnected(id)
    nil
  end

  def queue
    jobs.where(status: 'enqueued').order(created_at: :asc)
  end

  def next_job
    queue.first
  end

  def update_subscribers
    TentaclesSchema.subscriptions.trigger(:printer_subscription, { id: }, {})
  end

  def start_print
    REDIS_POOL.with do |conn|
      conn.publish('printers', { command: :start_print, printer_id: id }.to_json)
    end
  end

  private

  def api_client
    @api_client ||= Octoprint::Client.new(host: octoprint_uri, api_key: octoprint_key)
  end
end
