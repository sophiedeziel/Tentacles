# typed: true
# frozen_string_literal: true

class Printer
  class Status < ApplicationModel
    # Value equality for the snapshot and its parts: two of them with the same attributes are equal. The monitor
    # relies on it to compare snapshots.
    #
    #   Printer::Status::Camera.new(enabled: true) == Printer::Status::Camera.new(enabled: true) # => true
    module Equality
      extend ActiveSupport::Concern

      #: (untyped other) -> bool
      def ==(other)
        #: self as ApplicationModel
        other.instance_of?(self.class) && other.attributes == attributes
      end
      alias eql? ==

      #: -> Integer
      def hash
        #: self as ApplicationModel
        [self.class, attributes].hash
      end
    end
  end
end
