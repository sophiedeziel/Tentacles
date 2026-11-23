# typed: true
# frozen_string_literal: true

module Types
  # GraphQL has no URL type (the spec only defines Int, Float, String, Boolean and ID), so this is a custom scalar,
  # named and specified like the URL scalar of graphql-scalars. On the wire it is a string.
  class Url < Base::Scalar
    graphql_name 'URL'
    description 'An absolute HTTP or HTTPS URL, e.g. "http://192.168.1.57/"'
    specified_by_url 'https://url.spec.whatwg.org/'

    # A blank string (an empty form field) passes through, so the model's presence validations report it as blank
    # (graphql-ruby counts a nil result as a failed coercion)
    #: (untyped value, untyped _context) -> String
    def self.coerce_input(value, _context)
      return '' if value.to_s.strip.empty?

      uri = URI.parse(value.to_s)
      return uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?

      raise GraphQL::CoercionError, "#{value.inspect} is not an absolute http(s) URL"
    rescue URI::InvalidURIError
      raise GraphQL::CoercionError, "#{value.inspect} is not a valid URL"
    end

    #: (untyped value, untyped _context) -> String
    def self.coerce_result(value, _context)
      value.to_s
    end
  end
end
