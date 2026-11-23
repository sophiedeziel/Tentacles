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
      include ActiveModel::Serializers::JSON

      #: (?untyped _options) -> Hash[String, untyped]
      def serializable_hash(_options = nil)
        #: self as ApplicationModel
        attribute_names.index_with { |name| self.class.attribute_types.fetch(name).serialize(public_send(name)) }
      end

      #: (String json, ?untyped _include_root) -> self
      def from_json(json, _include_root = nil)
        model = self #: as ApplicationModel
        model.assign_attributes(ActiveSupport::JSON.decode(json).slice(*model.attribute_names))
        self
      end
    end
  end
end
