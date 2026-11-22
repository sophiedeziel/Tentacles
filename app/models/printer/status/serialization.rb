# typed: true
# frozen_string_literal: true

class Printer
  class Status < ApplicationModel
    # The JSON of the snapshot and its parts: their attributes, as their types serialize them (enums by value, times
    # as ISO 8601 in UTC). `new.from_json(json)` reads it back, ignoring the keys that aren't attributes (anymore).
    #
    #   camera.to_json                               # => '{"enabled":true,"stream_url":null}'
    #   Printer::Status::Camera.new.from_json(json) # => Printer::Status::Camera
    module Serialization
      extend ActiveSupport::Concern
      extend T::Sig
      include ActiveModel::Serializers::JSON

      sig { params(_options: T.untyped).returns(T::Hash[String, T.untyped]) }
      def serializable_hash(_options = nil)
        T.bind(self, ApplicationModel)
        attribute_names.index_with { |name| self.class.attribute_types.fetch(name).serialize(public_send(name)) }
      end

      sig { params(json: String, _include_root: T.untyped).returns(T.self_type) }
      def from_json(json, _include_root = nil)
        model = T.cast(self, ApplicationModel)
        model.assign_attributes(ActiveSupport::JSON.decode(json).slice(*model.attribute_names))
        self
      end
    end
  end
end
