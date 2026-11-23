# frozen_string_literal: true

module RootOperations
  class Query < Base::Object
    # Add `node(id: ID!) and `nodes(ids: [ID!]!)`
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    field :printers, [Types::Printer], null: false,
                                       description: 'asdf'
    def printers
      ::Printer.all
    end

    field :printer, Types::Printer, null: true, description: 'The printer, null when there is none with that id' do
      argument :id, ID, required: true
    end
    def printer(id:)
      ::Printer.find_by(id:)
    end

    field :files, [Types::File], null: false do
      description 'files'
    end
    def files
      ::Library::Item.includes(:labels).with_attached_file
    end

    field :file, Types::File, null: true do
      argument :id, ID, required: true
    end
    def file(id:)
      ::Library::Item.find_by(id: id)
    end

    field :labels, Types::Label.connection_type, null: false do
      description 'labels'
    end
    def labels
      ::Library::Label.all
    end

    field :label, Types::Label, null: true do
      argument :id, ID, required: true
    end
    def label(id:)
      ::Library::Label.find_by(id: id)
    end

    field :network_printers, resolver: Resolvers::NetworkPrinters

    field :identify_printer, resolver: Resolvers::IdentifyPrinter

    field :dashboard, Types::Dashboard, null: false,
                                        description: 'The dashboard layout, created from the default layout the ' \
                                                     'first time'
    def dashboard
      ::Dashboard::Section.ensure_default!
      Types::Dashboard.saved
    end

    field :default_dashboard, Types::Dashboard, null: false,
                                                description: 'The default layout, not saved (null ids): a Print ' \
                                                             'Queue XL for all printers, then a Printer M per printer'
    def default_dashboard
      { sections: ::Dashboard::Section.build_default, updated_at: nil }
    end

    # The most rows a queue or history field returns: the largest widget shows 16
    MAX_JOB_ROWS = 50

    field :print_queue, Types::PrintQueue, null: false do
      description 'The enqueued jobs of every printer, or of one, in the order the spooler starts them'
      argument :printer_id, ID, required: false, description: 'Only this printer\'s queue (all printers when null)'
      argument :first, Int, required: true, description: 'How many jobs to return',
                            validates: { numericality: { within: 0..MAX_JOB_ROWS } }
    end
    def print_queue(first:, printer_id: nil)
      { scope: jobs_of(printer_id).enqueued.in_queue_order, first: }
    end

    field :job_history, [Types::EnqueuedJob], null: false do
      description 'The finished jobs of every printer, or of one, the last finished first. The status is as ' \
                  'stored: completed, error, ...'
      argument :printer_id, ID, required: false, description: 'Only this printer\'s jobs (all printers when null)'
      argument :first, Int, required: true, description: 'How many jobs to return',
                            validates: { numericality: { within: 0..MAX_JOB_ROWS } }
    end
    def job_history(first:, printer_id: nil)
      jobs_of(printer_id).finished.newest_first.limit(first).includes(executable: { file_attachment: :blob })
    end

    field :global_queue, Types::GlobalQueue, null: true, description: 'The global print queue, null while it is off'
    def global_queue = ({} if ::PrintQueue.enabled?)

    field :monitor_healthy, Boolean, null: false,
                                     resolver_method: :monitor_healthy?,
                                     description: 'Whether the printer monitor reported in the last 15 seconds'
    def monitor_healthy?
      ::Printer::Monitor::Heartbeat.healthy?
    end

    field :filament_materials, [String], null: false,
                                         description: 'The materials a loaded filament can be, e.g. "PLA", "PETG"'
    def filament_materials
      ::Filament::MATERIALS
    end

    field :filament_colours, [String], null: false,
                                       description: 'Colours to suggest for a loaded filament: a short default ' \
                                                    'list, then every colour in use (alphabetical), each colour ' \
                                                    'once whatever its spelling'
    def filament_colours
      ::Filament.colour_suggestions
    end

    private

    def jobs_of(printer_id)
      printer_id ? ::Printer::Job.where(printer_id:) : ::Printer::Job.all
    end
  end
end
