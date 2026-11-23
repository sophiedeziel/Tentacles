# typed: true
# frozen_string_literal: true

module Sources
  # The G-code summaries of many files, with their tools, in two queries: File.gcodeSummary in a list of files.
  #
  #   dataloader.with(Sources::GcodeSummarySource).load(item.id) # => a ::Library::GcodeSummary, or nil
  class GcodeSummarySource < GraphQL::Dataloader::Source
    #: (Array[Integer] item_ids) -> Array[::Library::GcodeSummary?]
    def fetch(item_ids)
      summaries = ::Library::GcodeSummary.where(file_record_id: item_ids).includes(:tools).index_by(&:file_record_id)
      item_ids.map { |item_id| summaries[item_id] }
    end
  end
end
