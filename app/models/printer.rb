# frozen_string_literal: true

class Printer < ApplicationRecord
  def octoprint_version
    client = Octoprint::Client.new(host: octoprint_uri, api_key: octoprint_key)

    Octoprint::ServerVersion.get(client: client)
  rescue StandardError
    nil
  end
end
