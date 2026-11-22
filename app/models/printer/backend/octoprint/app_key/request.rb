# typed: strict
# frozen_string_literal: true

class Printer
  class Backend
    class Octoprint
      class AppKey
        # Asks OctoPrint for a key for Tentacles (POST /plugin/appkeys/request):
        #
        #   request = Printer::Backend::Octoprint::AppKey::Request.create!(url: 'http://192.168.1.57/')
        #   request.app_token       # follow it with AppKey::Poll
        #   request.auth_dialog_url # where the user approves it (OctoPrint 1.8+; nil before)
        class Request < AppKey
          sig { returns(T.nilable(String)) }
          attr_reader :app_token, :auth_dialog_url

          private

          sig { void }
          def persist
            response = http { |connection| connection.post('plugin/appkeys/request', { app: APP_NAME }.to_json) }
            raise_unless_created(response)

            body = parse(response)
            @app_token = T.let(string(body, 'app_token'), T.nilable(String))
            @auth_dialog_url = T.let(body['auth_dialog'].presence, T.nilable(String))
          end

          sig { params(response: Faraday::Response).void }
          def raise_unless_created(response)
            case response.status
            when 201 then nil
            # OctoPrint takes 3 requests a minute at most
            when 429
              raise Printer::Backend::Error, "OctoPrint at #{url} got too many requests. Try again in a minute."
            else
              raise Printer::Backend::Error, "OctoPrint at #{url} refused the request (HTTP #{response.status}). " \
                                             'Is its Application Keys plugin enabled?'
            end
          end
        end
      end
    end
  end
end
