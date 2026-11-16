# typed: true
# frozen_string_literal: true

module Types
  # GraphQL has no URL type (the spec only defines Int, Float, String, Boolean and ID), so this is a custom scalar,
  # named and specified like the URL scalar of graphql-scalars. On the wire it is a string.
  class Url < Base::Scalar
    extend T::Sig

    graphql_name 'URL'
    description 'An absolute HTTP or HTTPS URL, e.g. "http://192.168.1.57/"'
    specified_by_url 'https://url.spec.whatwg.org/'

    sig { params(value: T.untyped, _context: T.untyped).returns(String) }
    def self.coerce_input(value, _context)
      uri = URI.parse(value.to_s)
      return uri.to_s if uri.is_a?(URI::HTTP) && uri.host.present?

      raise GraphQL::CoercionError, "#{value.inspect} is not an absolute http(s) URL"
    rescue URI::InvalidURIError
      raise GraphQL::CoercionError, "#{value.inspect} is not a valid URL"
    end

    sig { params(value: T.untyped, _context: T.untyped).returns(String) }
    def self.coerce_result(value, _context)
      value.to_s
    end
  end
end
