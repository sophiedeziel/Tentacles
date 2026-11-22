# typed: strict
# frozen_string_literal: true

class OctoprintAppKey
  # Asks OctoPrint whether the user decided on a key request (GET /plugin/appkeys/request/<app_token>):
  #
  #   poll = OctoprintAppKey::Poll.create!(url: 'http://192.168.1.57/', app_token:)
  #   poll.decision # :waiting until the user decides, :approved, or :denied (denied, or expired)
  #   poll.api_key  # the new key once :approved, nil otherwise
  class Poll < OctoprintAppKey
    # The app token of OctoprintAppKey::Request
    attribute :app_token, :string

    validates :app_token, presence: true

    sig { returns(T.nilable(Symbol)) }
    attr_reader :decision

    sig { returns(T.nilable(String)) }
    attr_reader :api_key

    private

    sig { void }
    def persist
      response = http { |connection| connection.get("plugin/appkeys/request/#{app_token}") }
      decision = decision_of(response)
      # Read before anything is set: an unreadable approval leaves no decision behind
      api_key = string(parse(response), 'api_key') if decision == :approved
      @decision = T.let(decision, T.nilable(Symbol))
      @api_key = T.let(api_key, T.nilable(String))
    end

    sig { params(response: Faraday::Response).returns(Symbol) }
    def decision_of(response)
      case response.status
      when 202 then :waiting
      when 404 then :denied
      when 200 then :approved
      else raise Printer::Backend::Error, "OctoPrint at #{url} answered HTTP #{response.status}"
      end
    end
  end
end
