# frozen_string_literal: true

module Types
  # A Hash: { scope: the enqueued jobs (in queue order), first: how many to return }. See Query.printQueue.
  class PrintQueue < Base::Object
    description 'The jobs waiting to print, in the order the spooler starts them'

    field :jobs, [Types::EnqueuedJob], null: false, description: 'The first jobs of the queue, files preloaded'
    def jobs
      object[:scope].limit(object[:first]).includes(executable: { file_attachment: :blob })
    end

    field :total_count, Integer, null: false, description: 'How many jobs wait, including the ones not returned'
    def total_count
      object[:scope].unscope(:order).count
    end
  end
end
