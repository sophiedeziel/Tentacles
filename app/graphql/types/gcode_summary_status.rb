# frozen_string_literal: true

module Types
  class GcodeSummaryStatus < Base::Enum
    description 'Where the reading of a G-code file is (see File.gcodeSummary)'

    value 'PENDING', 'Not read yet: being read, or waiting to be. Refetch until it changes', value: 'pending'
    value 'READY', 'Read: every value that could be read is set, the others are null (Not known)', value: 'ready'
    value 'FAILED', 'The file could not be read (see error). reanalyseGcode reads it again', value: 'failed'
  end
end
