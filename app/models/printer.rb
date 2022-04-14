# frozen_string_literal: true

class Printer < ApplicationRecord
  has_many :jobs, class_name: 'Printer::Job', dependent: :nullify

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

  def upload(file)
    using_api do
      Octoprint::Files.upload(file)
    end
  end

  private

  def using_api(&block)
    api_client.use(&block)
  end

  def api_client
    @api_client ||= Octoprint::Client.new(host: octoprint_uri, api_key: octoprint_key)
  end
end
