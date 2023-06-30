# frozen_string_literal: true

class Printer < ApplicationRecord
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
    using_api(cache: 2.minutes) do
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

  def upload(file, **options)
    using_api do
      Octoprint::Files.upload(file, **options)
    end
  end

  def using_api(cache: false, &)
    cache_key = "printer_#{id}_#{caller[0][/`.*'/][1..-2]}"
    use_cache(key: cache_key, time: cache) do
      api_client.use(&)
    rescue StandardError => e
      Rails.logger.error("Failed to get OctoPrint data for #{name} :\n\t#{e.message}")
      nil
    end
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

  def use_cache(key:, time:, &)
    return yield if time.nil?

    cached_result = REDIS_POOL.with do |conn|
      JSON.parse(conn.get(key)).deep_symbolize_keys
    end

    if cached_result.present? && cached_result[:expiration] < Time.now.to_i
      case cached_result[:object_type]
      when "NilClass", "String", "Integer", "Float", "TrueClass", "FalseClass"
        return cached_result[:value]
      when "Hash"
        return cached_result[:value]
      when "Symbol"
        return cached_result[:value].to_sym
      else
        return cached_result[:object_type].constantize.new(**cached_result[:value])
      end
    end

    yield.tap do |result|
      REDIS_POOL.with do |conn|
        conn.set(key, { value: result, expiration: (Time.now + time).to_i, object_type: result.class }.to_json)
      end
    end
  end
end
