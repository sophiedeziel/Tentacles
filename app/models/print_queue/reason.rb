# typed: true
# frozen_string_literal: true

module PrintQueue
  # Why the queue's rules answered what they did: a `code` the code branches on, and a `message` shown to people.
  # Every PrintQueue::Fit carries at least one (`:ready` included), and so does every idle PrintQueue::Readiness.
  #
  #   reason = PrintQueue::Reason.new(code: :wrong_material, message: 'Loaded PETG Black, needs PLA')
  #   reason.code    # => :wrong_material
  #   reason.message # => "Loaded PETG Black, needs PLA"
  class Reason < ApplicationModel
    # A Symbol
    attribute :code
    attribute :message, :string

    #: -> Hash[Symbol, untyped]
    def to_h = { code:, message: }

    # A value the rules build: nothing to save
    # @override
    #: -> bool
    def readonly? = true
  end
end
