# frozen_string_literal: true

require 'rails_helper'

# Printer.bedNeedsClearing and printOnBed: the print confirmBedCleared's expectedPrintId names
RSpec.describe 'Query printer, its bed', type: :request do
  before { allow(PrintQueue).to receive(:enabled?).and_return(true) }

  def run(query, variables = {})
    post '/graphql', params: { query:, variables: variables.to_json }
    body = response.parsed_body
    expect(body['errors']).to be_nil
    body['data']
  end

  def printer_fields(printer, fields)
    run("query($id: ID!) { printer(id: $id) { #{fields} } }", id: printer.id)['printer']
  end

  # The SQL queries the block runs, the ones the query cache answers included
  def sql_queries(&)
    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name])
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    queries
  end

  # A copy that started 2 hours ago and finished an hour ago: on the bed until it's cleared
  def finished_copy(printer)
    create(:printer_job, :copy, printer:, status: 'completed', started_at: 2.hours.ago, finished_at: 1.hour.ago)
  end

  it 'gives the print still on the bed' do
    mk4 = create(:printer, name: 'Prusa MK4')
    on_bed = finished_copy(mk4)
    clear = create(:printer, name: 'Clear')

    fields = 'bedNeedsClearing printOnBed { id printJob { file { filename } } }'

    expect(printer_fields(mk4, fields)).to eq(
      'bedNeedsClearing' => true,
      'printOnBed' => { 'id' => on_bed.id.to_s, 'printJob' => { 'file' => { 'filename' => 'test.gcode' } } }
    )
    expect(printer_fields(clear, fields)).to eq('bedNeedsClearing' => false, 'printOnBed' => nil)
  end

  it 'reads one query for every printer of a list' do
    3.times { |index| finished_copy(create(:printer, name: "Printer #{index}")) }

    queries = sql_queries { run('{ printers { id bedNeedsClearing printOnBed { id } } }') }

    expect(queries.grep(/ROW_NUMBER/).size).to eq 1
  end

  it 'says the bed is clear while the global queue is off' do
    mk4 = create(:printer)
    finished_copy(mk4)
    allow(PrintQueue).to receive(:enabled?).and_return(false)

    expect(printer_fields(mk4, 'bedNeedsClearing printOnBed { id }'))
      .to eq('bedNeedsClearing' => false, 'printOnBed' => nil)
  end
end
