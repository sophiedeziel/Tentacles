# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query printers { queuedCount nextJob }', type: :request do
  let(:redis) { MockRedis.new }
  let(:query) { 'query { printers { id queuedCount nextJob { id executable { id filename } } } }' }
  let(:json) { response.parsed_body }
  let(:printers) { json['data']['printers'].index_by { |printer| printer['id'].to_i } }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  def enqueue(printer, status = 'enqueued', created_at: Time.current)
    create(:printer_job, printer:, status:, created_at:)
  end

  def sql_queries(&)
    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    queries
  end

  it 'counts the enqueued jobs and returns the first one, in queue order' do
    printer = create(:printer)
    enqueue(printer, created_at: 1.minute.ago)
    first = enqueue(printer, created_at: 1.hour.ago)
    enqueue(printer, 'active', created_at: 2.hours.ago)
    enqueue(printer, 'completed', created_at: 3.hours.ago)

    post '/graphql', params: { query: }

    expect(json['errors']).to be_nil
    expect(printers[printer.id]).to include('queuedCount' => 2,
                                            'nextJob' => { 'id' => first.id.to_s,
                                                           'executable' => { 'id' => first.executable_id.to_s,
                                                                             'filename' => 'test.gcode' } })
    expect(printer.next_job).to eq(first)
  end

  it 'breaks created_at ties by id, like the spooler' do
    printer = create(:printer)
    at = 1.hour.ago.change(usec: 0)
    first = enqueue(printer, created_at: at)
    enqueue(printer, created_at: at)

    post '/graphql', params: { query: }

    expect(printers[printer.id]['nextJob']['id']).to eq(first.id.to_s)
    expect(printer.next_job).to eq(first) # the spooler starts the same job
  end

  it 'is empty for a printer with nothing enqueued' do
    printer = create(:printer)
    enqueue(printer, 'active')
    enqueue(printer, 'error')

    post '/graphql', params: { query: }

    expect(printers[printer.id]).to include('queuedCount' => 0, 'nextJob' => nil)
  end

  it 'resolves each printer on its own' do
    busy = create(:printer).tap { |printer| 3.times { enqueue(printer) } }
    idle = create(:printer)
    single = create(:printer).tap { |printer| enqueue(printer) }

    post '/graphql', params: { query: }

    expect(printers.transform_values { |printer| printer['queuedCount'] }).to eq(busy.id => 3, idle.id => 0,
                                                                                 single.id => 1)
  end

  describe 'batching' do
    let(:dashboard_query) do
      'query { printers { id canStartNext queuedCount nextJob { id executable { id filename } } } }'
    end

    def query_count(printer_count)
      Printer::Job.delete_all
      Printer.delete_all
      Array.new(printer_count) { create(:printer).tap { |printer| 2.times { enqueue(printer) } } }
      sql_queries { post '/graphql', params: { query: dashboard_query } }.size
    end

    it 'issues the same number of SQL queries for 1 and 5 printers' do
      expect(query_count(5)).to eq(query_count(1))
      expect(json['data']['printers'].size).to eq 1
    end

    it 'reads the jobs with one query shared with canStartNext, never calling OctoPrint' do
      3.times { create(:printer).tap { |printer| enqueue(printer) } }
      expect(Octoprint::Client).not_to receive(:new)

      queries = sql_queries { post '/graphql', params: { query: dashboard_query } }

      expect(json['errors']).to be_nil
      expect(queries.grep(/FROM `printer_jobs`|FROM \(SELECT printer_jobs/).size).to eq 1
    end
  end

  it 'can be broadcast by printerStatusChanged' do
    subscription = 'subscription { printerStatusChanged { id queuedCount nextJob { id executable { id filename } } } }'

    expect(TentaclesSchema.subscriptions.broadcastable?(subscription)).to be(true)
  end
end
