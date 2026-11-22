# typed: true
# frozen_string_literal: true

module Resolvers
  # Tests the credentials of a printer before it's added, or while it's edited: reads its name and server version
  # through the backend's adapter (see Printer::Backend#identify), from the server, so the browser never deals
  # with CORS or Digest auth. With `printerId`, a blank secret is that printer's saved one (the page never shows it).
  #
  # Failures are GraphQL errors with a code in `extensions.code`: UNAUTHORIZED (rejected credentials), UNREACHABLE
  # (no answer), PRINTER_ERROR (anything else). Their messages never contain the secret.
  class IdentifyPrinter < GraphQL::Schema::Resolver
    extend T::Sig

    # Characters kept from the error's own message
    DETAIL_LENGTH = 120

    argument_class Base::Argument

    description "Reads a printer's name and server version with the given credentials, without saving anything"

    type Types::PrinterIdentity, null: false

    argument :backend, Types::PrinterBackend, required: true
    argument :uri, Types::Url, required: true, description: "The URL of the printer's server"
    argument :username, String, required: false, description: 'The username, for PrusaLink (default: "maker")'
    argument :secret, String, required: false,
                              description: "OctoPrint's API key, or PrusaLink's password. Blank with `printerId`: " \
                                           "that printer's saved one."
    argument :printer_id, ID, required: false, description: 'The saved printer being edited, for its saved secret'

    sig do
      params(backend: String, uri: String, username: T.nilable(String), secret: T.nilable(String),
             printer_id: T.nilable(String)).returns(T::Hash[Symbol, T.nilable(String)])
    end
    def resolve(backend:, uri:, username: nil, secret: nil, printer_id: nil)
      key = secret.presence || saved_secret(printer_id)
      printer = ::Printer.new(backend:, uri: uri.presence, username: username.presence, secret: key)
      printer.api.identify
    # JSON::ParserError and KeyError: the octoprint gem fails to read the error of a server that isn't OctoPrint
    rescue Printer::Backend::Error, JSON::ParserError, KeyError, URI::InvalidURIError => e
      raise execution_error(T.must(printer).api, uri, key.to_s, e)
    end

    private

    # The secret saved for that printer: nil without a printer, or when it can't be decrypted (it must be entered again)
    sig { params(printer_id: T.nilable(String)).returns(T.nilable(String)) }
    def saved_secret(printer_id)
      return if printer_id.nil?

      printer = ::Printer.find_by(id: printer_id)
      raise GraphQL::ExecutionError.new('Printer not found', extensions: { code: 'PRINTER_ERROR' }) if printer.nil?

      printer.readable_secret
    end

    sig do
      params(api: Printer::Backend, uri: String, secret: String, error: StandardError)
        .returns(GraphQL::ExecutionError)
    end
    def execution_error(api, uri, secret, error)
      warning = "[identifyPrinter] Could not identify the #{api.product_name} at #{uri.inspect}: #{error.class}"
      Rails.logger.warn(redact(warning, secret))
      message = message(api, uri, error, detail(error, secret))
      GraphQL::ExecutionError.new(redact(message, secret), extensions: { code: code(error) })
    end

    sig { params(error: StandardError).returns(String) }
    def code(error)
      case error
      when Printer::Backend::Unauthorized then 'UNAUTHORIZED'
      when Printer::Backend::Unreachable then 'UNREACHABLE'
      else 'PRINTER_ERROR'
      end
    end

    # The first line of the error's message, short: the gems put the server's whole answer (an HTML page, ...) in it.
    # Redacted before it's cut, so that no part of the secret survives.
    sig { params(error: StandardError, secret: String).returns(String) }
    def detail(error, secret)
      redact(error.message, secret).lines.first.to_s.squish.truncate(DETAIL_LENGTH)
    end

    # `detail`: see #detail
    sig { params(api: Printer::Backend, uri: String, error: StandardError, detail: String).returns(String) }
    def message(api, uri, error, detail)
      product = api.product_name
      case error
      when Printer::Backend::Unauthorized
        "#{product} rejected the #{api.is_a?(Printer::Backend::Prusalink) ? 'username or password' : api.secret_name}"
      when Printer::Backend::Unreachable then "Could not reach #{product} at #{uri}: #{detail}"
      when Printer::Backend::MissingCredentials then "Enter the URL and the #{api.secret_name}"
      when URI::InvalidURIError then "#{uri} is not a valid URL"
      when Printer::Backend::Error then "#{product} returned an error: #{detail}"
      else "#{uri} does not answer like #{product}" # JSON::ParserError, KeyError: e.g. an HTML page
      end
    end

    # Never echo the secret back, whatever ends up in a message
    sig { params(message: String, secret: String).returns(String) }
    def redact(message, secret)
      secret.present? ? message.gsub(secret, '[FILTERED]') : message
    end
  end
end
