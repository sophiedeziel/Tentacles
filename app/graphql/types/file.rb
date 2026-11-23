# frozen_string_literal: true

module Types
  class File < Base::Object
    # Broadcastable: printerStatusChanged can select Printer.nextJob's file name
    field :id, ID, null: false, broadcastable: true
    field :filename, String, null: false, broadcastable: true
    field :notes, String, null: false
    field :filetype, String, null: false
    field :filesize, Integer, null: false
    field :is_archived, Boolean, null: false, method: :archived?
    field :is_deleted, Boolean, null: false, method: :deleted?
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :archived_at, GraphQL::Types::ISO8601DateTime, null: true
    field :download_url, Types::Url, null: false
    field :top_file_comments, String, null: true
    field :file_content, String, null: true
    field :gcode_analysis, Types::GcodeAnalysis, null: true
    field :gcode_summary, Types::GcodeSummary, null: true,
                                               description: 'What the file needs to print: null when it is not ' \
                                                            'G-code, PENDING until it is read'
    field :labels, Label.connection_type, null: false

    # Batched for a list of files. A file not read yet has no row: an unsaved one reads PENDING
    def gcode_summary
      return unless object.gcode?

      dataloader.with(Sources::GcodeSummarySource).load(object.id) ||
        ::Library::GcodeSummary.new(file_record_id: object.id)
    end
  end
end
