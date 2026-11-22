# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query printers { canStartNext }', type: :request do
  let(:redis) { MockRedis.new }
  let(:query) { 'query { printers { id canStartNext } }' }
  let(:json) { response.parsed_body }
  let(:can_start_next) { json['data']['printers'].to_h { |printer| [printer['id'].to_i, printer['canStartNext']] } }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  def snapshot(printer, family = Printer::StateFamily::Operational)
    Printer::Status.new(printer_id: printer.id, state_family: family,
                        state_text: family.serialize).save!
  end

  def enqueue(printer, status = 'enqueued')
    create(:printer_job, printer:, status:)
  end

  # Printer ready to start its next job: OPERATIONAL, with a queue and no active job
  def ready_printer
    create(:printer).tap do |printer|
      snapshot(printer)
      enqueue(printer)
    end
  end

  def sql_queries(&)
    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    queries
  end

  it 'is true when the printer is OPERATIONAL, has a queue and no active job' do
    printer = ready_printer
    post '/graphql', params: { query: }
    expect(json['errors']).to be_nil
    expect(can_start_next[printer.id]).to be true
  end

  (Printer::StateFamily.values - [Printer::StateFamily::Operational]).each do |family|
    it "is false when the printer is #{family.serialize}" do
      printer = ready_printer
      snapshot(printer, family)
      post '/graphql', params: { query: }
      expect(can_start_next[printer.id]).to be false
    end
  end

  it 'is false when the monitor has no snapshot of the printer' do
    printer = create(:printer)
    enqueue(printer)
    post '/graphql', params: { query: }
    expect(can_start_next[printer.id]).to be false
  end

  it 'is false when Redis is down' do
    printer = ready_printer
    allow(redis).to receive(:mget).and_raise(Redis::CannotConnectError)
    post '/graphql', params: { query: }
    expect(json['errors']).to be_nil
    expect(can_start_next[printer.id]).to be false
  end

  it 'is false when the queue is empty' do
    printer = create(:printer)
    snapshot(printer)
    enqueue(printer, 'completed')
    enqueue(printer, 'error')
    enqueue(create(:printer)) # another printer's queue
    post '/graphql', params: { query: }
    expect(can_start_next[printer.id]).to be false
  end

  it 'is false when the printer has an active job' do
    printer = ready_printer
    enqueue(printer, 'active')
    post '/graphql', params: { query: }
    expect(can_start_next[printer.id]).to be false
  end

  it 'resolves each printer on its own' do
    ready = ready_printer
    busy = ready_printer.tap { |printer| enqueue(printer, 'active') }
    idle = create(:printer).tap { |printer| snapshot(printer) }
    post '/graphql', params: { query: }
    expect(can_start_next).to eq(ready.id => true, busy.id => false, idle.id => false)
  end

  describe 'batching' do
    def query_count(printer_count)
      Printer::Job.delete_all
      Printer.delete_all
      Array.new(printer_count) { ready_printer.tap { |printer| enqueue(printer, 'active') if printer.id.even? } }
      sql_queries { post '/graphql', params: { query: } }.size
    end

    it 'issues the same number of SQL queries for 1 and 5 printers' do
      expect(query_count(5)).to eq(query_count(1))
      expect(json['data']['printers'].size).to eq 1
    end

    it 'reads the jobs with one grouped query' do
      3.times { ready_printer }
      queries = sql_queries { post '/graphql', params: { query: } }
      expect(queries.grep(/printer_jobs/).size).to eq 1
    end

    it 'reads every snapshot with a single Redis MGET, shared with status, never calling OctoPrint' do
      5.times { ready_printer }
      expect(redis).to receive(:mget).once.and_call_original
      expect(redis).not_to receive(:get)
      expect(Octoprint::Client).not_to receive(:new)

      post '/graphql', params: { query: 'query { printers { id canStartNext status { stateFamily } } }' }

      expect(json['errors']).to be_nil
      expect(can_start_next.values).to all(be true)
    end
  end
end
