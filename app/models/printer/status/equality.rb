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
      extend T::Sig

      sig { params(other: T.untyped).returns(T::Boolean) }
      def ==(other)
        T.bind(self, ApplicationModel)
        other.instance_of?(self.class) && other.attributes == attributes
      end
      alias eql? ==

      sig { returns(Integer) }
      def hash
        T.bind(self, ApplicationModel)
        [self.class, attributes].hash
      end
    end
  end
end
