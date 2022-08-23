# frozen_string_literal: true

class Printer < ApplicationRecord
  has_many :jobs, class_name: 'Printer::Job', dependent: :nullify

  validates :name, presence: true

  def self.table_name_prefix
    return '' if self == Printer

    'printer_'
  end

  def octoprint_version
    using_api do
      return Octoprint::ServerVersion.get
    end
  end

  def job_status
    using_api do
      Octoprint::Job.get.state
    end
  end

  def upload(file, **options)
    using_api do
      Octoprint::Files.upload(file, **options)
    end
  end

  def using_api(&block)
    api_client.use(&block)
  end

  def queue
    jobs.where(status: 'enqueued').order(created_at: :asc)
  end

  def next_job
    queue.first
  end

  private

  def api_client
    @api_client ||= Octoprint::Client.new(host: octoprint_uri, api_key: octoprint_key)
  end
end
