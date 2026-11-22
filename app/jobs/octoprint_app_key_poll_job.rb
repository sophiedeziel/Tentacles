# typed: strict
# frozen_string_literal: true

# Follows an OctoPrint app key request (see requestPrinterAppKey) until the user decides in OctoPrint:
#
# - 202: still waiting, poll again
# - 200: approved. Identifies the printer with the key and adds it (Printer::Addition), then pushes ADDED with it
# - 404: denied or expired, pushes DENIED
# - OctoPrint unreachable, or the printer can't be added: pushes FAILED with the reason
#
# OctoPrint drops a request that isn't polled for 5 seconds (POLL_TIMEOUT in its appkeys plugin), and Sidekiq starts
# scheduled jobs up to ~7.5 seconds late (it checks them every 2.5 to 7.5 s), so a `set(wait: 1.second)` re-enqueue
# would lose requests. Each run polls POLLS_PER_RUN times, a second apart, then enqueues the next run right away:
# a worker thread is busy for about POLLS_PER_RUN seconds at a time, not for the whole wait.
#
# Stops when the request is gone from Redis: cancelled (cancelPrinterAppKeyRequest) or expired. The API key is only
# held in memory here and saved with the printer: it's never pushed, stored in Redis or logged.
class OctoprintAppKeyPollJob < ApplicationJob
  extend T::Sig

  queue_as :default

  POLL_INTERVAL = 1 # second
  POLLS_PER_RUN = 5

  sig { params(request_id: String).void }
  def perform(request_id)
    waiting = POLLS_PER_RUN.times.all? do |index|
      sleep(POLL_INTERVAL) if index.positive?
      waiting_after_poll?(request_id)
    end
    self.class.perform_later(request_id) if waiting
  rescue Printer::Backend::Error => e
    fail_request(Printer::AppKeyRequest.take(request_id), e.message, e)
  end

  private

  # Polls OctoPrint once. true while the user hasn't decided; false once the request is over: finished here, or gone
  # from Redis (cancelled or expired), in which case OctoPrint isn't called.
  sig { params(request_id: String).returns(T::Boolean) }
  def waiting_after_poll?(request_id)
    request = Printer::AppKeyRequest.find(request_id)
    return false if request.nil?

    poll = Printer::Backend::Octoprint::AppKey::Poll.create!(url: request.url, app_token: request.app_token)
    return true if poll.decision == :waiting

    finish(request_id, poll.api_key)
    false
  end

  # Denied when there's no key. The request is taken first: a cancel that comes later finds nothing, one that came
  # earlier wins.
  sig { params(request_id: String, api_key: T.nilable(String)).void }
  def finish(request_id, api_key)
    request = Printer::AppKeyRequest.take(request_id)
    return if request.nil?

    api_key ? add_printer(request, api_key) : request.push('denied')
  end

  sig { params(request: Printer::AppKeyRequest, api_key: String).void }
  def add_printer(request, api_key)
    addition = Printer::Addition.new(name: printer_name(request, api_key), backend: 'octoprint', uri: request.url,
                                     secret: api_key)
    if addition.save
      request.push('added', printer: addition.printer)
    else
      request.push('failed', error: addition.errors.full_messages.to_sentence)
    end
  # JSON::ParserError and KeyError: the octoprint gem fails to read the error of a server that isn't OctoPrint
  rescue Printer::Backend::Error, JSON::ParserError, KeyError => e
    fail_request(request, identify_error(request.url, e), e)
  end

  # The name of OctoPrint's default printer profile, else the address
  sig { params(request: Printer::AppKeyRequest, api_key: String).returns(String) }
  def printer_name(request, api_key)
    name = ::Printer.new(backend: 'octoprint', uri: request.url, secret: api_key).api.identify[:name]
    name.presence || T.must(request.address)
  end

  # The gem's messages are not shown: they can hold anything the server answered
  sig { params(url: String, error: StandardError).returns(String) }
  def identify_error(url, error)
    case error
    when Printer::Backend::Unreachable then "Could not reach OctoPrint at #{url}"
    when Printer::Backend::Unauthorized then 'OctoPrint rejected the new API key'
    else "OctoPrint at #{url} could not be read with the new API key"
    end
  end

  # `request`: taken from Redis, nil when it was already gone (cancelled meanwhile)
  sig { params(request: T.nilable(Printer::AppKeyRequest), message: String, error: StandardError).void }
  def fail_request(request, message, error)
    return if request.nil?

    Rails.logger.warn("[OctoprintAppKeyPollJob] Request #{request.id} at #{request.url} failed: #{error.class}")
    request.push('failed', error: message)
  end
end
