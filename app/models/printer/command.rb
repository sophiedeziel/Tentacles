# typed: true
# frozen_string_literal: true

class Printer
  # Base of the commands sent to a printer (Printer::Pause, Printer::Connection, ...).
  #
  #   pause = Printer::Pause.new(printer:, expected_file_name: 'cube.gcode')
  #   pause.save          # => false, with a readable message in errors[:base], when refused or when the printer fails
  #   pause.errors[:base] # => ['Prusa MK4 is now printing gear.gcode']
  #
  # Each command re-reads the printer's LIVE state from its API first (Printer::LiveJob, read once) and refuses,
  # without sending anything, when the printer isn't in a state that allows it. The refusals are validations, checked
  # in order, each one only when the previous ones passed, so that a single message comes back:
  # 1. the connection commands are refused for the backends that connect on their own (without reading the state)
  # 2. the state family must allow the command (#refusal)
  # 3. the live job must still be the file the user confirmed (`expected_file_name`, the file the screen showed): a
  #    stale screen must not pause or cancel another print
  # After the command, #persist runs one monitor tick (#refresh_status) so that the new state is pushed to the
  # subscribers before the response returns.
  #
  # #save doesn't raise for printer API or network failures: it returns false with a readable, redacted message in
  # `errors[:base]` (see #error_message_for). Reading the live job calls the printer, so #valid? raises them.
  #
  # Subclasses implement:
  # - `refusal(family)`: the error message when the command isn't allowed in that state family, else nil
  # - `send_command`: the command, sent through `printer.api` (with `live_job.job_id` for the job commands)
  # - `refresh_after_command?`, optionally: false to skip the monitor tick
  class Command < ApplicationModel
    extend T::Helpers

    abstract!

    attribute :printer
    # The file the user confirmed for, or nil not to check it
    attribute :expected_file_name, :string

    validates :printer, presence: true
    validate :connects_through_tentacles, if: :connection_command?, unless: :refused?
    validate :printer_allows_it, unless: :refused?
    validate :still_the_confirmed_job, unless: :refused?

    # Besides our own bugs: the adapter's errors, answers that aren't the server's (HTML: JSON::ParserError, no
    # `error` key: KeyError) and a malformed URL. The adapter wraps the network errors.
    rescue_into_errors Printer::Backend::Error, JSON::ParserError, KeyError, URI::InvalidURIError

    # The printer's state and job, read from the printer the first time it's needed (raises the adapter's errors)
    sig { returns(LiveJob) }
    def live_job
      @live_job ||= T.let(LiveJob.find_by(printer:), T.nilable(LiveJob))
    end

    private

    # The error message when the command isn't allowed in that state family, or nil when it is
    sig { abstract.params(family: Printer::StateFamily).returns(T.nilable(String)) }
    def refusal(family); end

    # Sends the command to the printer (raises the adapter's errors)
    sig { abstract.void }
    def send_command; end

    # Whether the monitor tick follows the command
    sig { returns(T::Boolean) }
    def refresh_after_command?
      true
    end

    sig { void }
    def persist
      send_command
      refresh_status if refresh_after_command?
    end

    # Whether the command connects the server to the printer. Refused, without reading the state, for the backends
    # that connect on their own (see Printer::Backend#connects_on_its_own?).
    sig { returns(T::Boolean) }
    def connection_command?
      false
    end

    sig { returns(T::Boolean) }
    def refused?
      errors.any?
    end

    sig { void }
    def connects_through_tentacles
      api = printer.api
      errors.add(:base, "#{api.product_name} printers connect on their own") if api.connects_on_its_own?
    end

    sig { void }
    def printer_allows_it
      message = refusal(T.must(live_job.state_family))
      errors.add(:base, message) if message
    end

    # The live job's file name is the one the monitor reports (Printer::Status#file_name)
    sig { void }
    def still_the_confirmed_job
      expected = expected_file_name
      return if expected.nil?

      current = live_job.file_name
      return if current == expected

      if current
        errors.add(:base, "#{printer.name} is now printing #{current}")
      else
        errors.add(:base, "#{printer.name} is no longer printing #{expected}")
      end
    end

    # One monitor tick for the printer, inline: reloads its status from the printer and saves it (which pushes
    # printerStatusChanged) if it changed. The camera of the last snapshot is kept: the webcam settings aren't read
    # again. Never raises: the monitor reports the printer on its next tick anyway.
    sig { void }
    def refresh_status
      status = Printer::Status.find_or_initialize_by(printer:).reload
      status.save! if status.changed?
    rescue StandardError => e
      Rails.logger.warn("[#{self.class.name}] #{printer.name} (##{printer.id}): Inline refresh failed: " \
                        "#{e.class}: #{e.message}")
    end

    sig { params(error: Exception).returns(String) }
    def error_message_for(error)
      product = printer.api.product_name
      case error
      when Backend::Error then backend_error_message(error, product)
      when URI::InvalidURIError then "#{printer.name} has an invalid #{product} URL"
      # The URL answers, but not like the server (e.g. an HTML page)
      when JSON::ParserError, KeyError then "#{printer.name}'s #{product} URL does not answer like #{product}"
      else super
      end
    end

    sig { params(error: Backend::Error, product: String).returns(String) }
    def backend_error_message(error, product)
      name = printer.name
      case error
      when Backend::UnreadableCredentials
        "#{name}'s stored #{product} #{printer.api.secret_name} can't be read, re-enter it"
      when Backend::MissingCredentials then "#{name} has no #{product} URL or #{printer.api.secret_name}"
      when Backend::NoJob then "#{name} has no job under way"
      when Backend::Unreachable then "Could not reach #{name}'s #{product}: #{redact(error.message)}"
      else "#{name}'s #{product} returned an error: #{redact(error.message)}"
      end
    end

    # Never echo the API key or password back, whatever ends up in an error message
    sig { params(message: String).returns(String) }
    def redact(message)
      key = printer.readable_secret
      key.present? ? message.gsub(key, '[FILTERED]') : message
    end
  end
end
