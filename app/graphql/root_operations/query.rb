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

    field :printer, Types::Printer, null: true do
      argument :id, ID, required: true
    end
    def printer(id:)
      ::Printer.find(id)
    end

    field :files, [Types::File], null: false do
      description 'files'
    end
    def files
      ::FileRecord.includes(:labels).with_attached_file
    end

    field :file, Types::File, null: true do
      argument :id, ID, required: true
    end
    def file(id:)
      ::FileRecord.find_by(id: id)
    end

    field :labels, Types::Label.connection_type, null: false do
      description 'labels'
    end
    def labels
      ::Label.all
    end

    field :label, Types::Label, null: true do
      argument :id, ID, required: true
    end
    def label(id:)
      ::Label.find_by(id: id)
    end

    field :search_network_printers, [String], null: true
    def search_network_printers
      ::PrinterScanner.new.call
    end

    field :identify_printer, resolver: Resolvers::IdentifyPrinter

    field :octoprint_name, String, null: true, deprecation_reason: 'Use `identifyPrinter`' do
      argument :octoprint_uri, String, required: true
      argument :octoprint_key, String, required: true
    end
    def octoprint_name(octoprint_uri:, octoprint_key:)
      ::Printer.new(backend: 'octoprint', uri: octoprint_uri, secret: octoprint_key).api.identify[:name]
    # JSON::ParserError and KeyError: the gem fails to read the error of a server that isn't OctoPrint
    rescue PrinterBackends::Error, JSON::ParserError, KeyError, URI::InvalidURIError => e
      Rails.logger.warn("[octoprintName] Could not get OctoPrint's name at #{octoprint_uri.inspect}: #{e.class}")
      nil
    end

    field :dashboard, Types::Dashboard, null: false,
                                        description: 'The dashboard layout, created from the default layout the ' \
                                                     'first time'
    def dashboard
      ::DashboardSection.ensure_default!
      Types::Dashboard.saved
    end

    field :default_dashboard, Types::Dashboard, null: false,
                                                description: 'The default layout, not saved (null ids): a Print ' \
                                                             'Queue XL for all printers, then a Printer M per printer'
    def default_dashboard
      { sections: ::DashboardSection.build_default, updated_at: nil }
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

    field :monitor_healthy, Boolean, null: false,
                                     resolver_method: :monitor_healthy?,
                                     description: 'Whether the printer monitor reported in the last 15 seconds'
    delegate :monitor_healthy?, to: :PrinterStatusStore

    private

    def jobs_of(printer_id)
      printer_id ? ::Printer::Job.where(printer_id:) : ::Printer::Job.all
    end
  end
end
