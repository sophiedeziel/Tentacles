# typed: true
# frozen_string_literal: true

module Sources
  # The PrintQueue::Fleet, read once per query (whatever key): the printer sections of globalQueue, the printers that
  # can print each print job and What Happens Next share it.
  #
  #   dataloader.with(Sources::FleetSource).load(:current) # => PrintQueue::Fleet
  class FleetSource < GraphQL::Dataloader::Source
    #: (Array[Symbol] keys) -> Array[::PrintQueue::Fleet]
    def fetch(keys)
      fleet = ::PrintQueue::Fleet.current
      keys.map { fleet }
    end
  end
end
