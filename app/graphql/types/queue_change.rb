# frozen_string_literal: true

module Types
  # The payload of queueChanged: small on purpose, clients refetch globalQueue
  class QueueChange < Base::Object
    description 'The global queue changed: refetch globalQueue'
    # Context-independent, so queueChanged can broadcast it
    default_broadcastable true

    field :dispatch_paused, Boolean, null: false, description: 'Whether dispatch is paused for the whole fleet'
  end
end
