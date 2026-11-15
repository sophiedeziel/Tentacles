# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query printQueue and jobHistory', type: :request do
  let(:redis) { MockRedis.new }
  let(:json) { response.parsed_body }
  let(:mk4) { create(:printer, name: 'Prusa MK4') }
  let(:mini) { create(:printer, name: 'Prusa Mini+') }

  before { stub_const('REDIS_POOL', ConnectionPool::Wrapper.new(size: 1, timeout: 1) { redis }) }

  def job(printer, status = 'enqueued', created_at: Time.current, updated_at: created_at)
    create(:printer_job, printer:, status:, created_at:, updated_at:)
  end

  def run(query, variables = {})
    post '/graphql', params: { query:, variables: variables.to_json }
    expect(json['errors']).to be_nil
    json['data']
  end

  def sql_queries(&)
    queries = []
    counter = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    queries
  end

  describe 'printQueue' do
    let(:query) do
      <<~GRAPHQL
        query($printerId: ID, $first: Int!) {
          printQueue(printerId: $printerId, first: $first) {
            totalCount
            jobs { id status executable { filename } printer { id name } }
          }
        }
      GRAPHQL
    end

    it 'lists the enqueued jobs of every printer in enqueue order, naming their printer' do
      second = job(mini, created_at: 2.hours.ago)
      first = job(mk4, created_at: 3.hours.ago)
      third = job(mk4, created_at: 1.hour.ago)
      job(mk4, 'active', created_at: 4.hours.ago)
      job(mini, 'completed', created_at: 5.hours.ago)

      queue = run(query, first: 10)['printQueue']

      expect(queue['totalCount']).to eq 3
      expect(queue['jobs'].pluck('id')).to eq([first, second, third].map { |queued| queued.id.to_s })
      expect(queue['jobs'].first).to eq('id' => first.id.to_s, 'status' => 'enqueued',
                                        'executable' => { 'filename' => 'test.gcode' },
                                        'printer' => { 'id' => mk4.id.to_s, 'name' => 'Prusa MK4' })
    end

    it 'returns the first jobs only, with the count of all of them' do
      jobs = Array.new(4) { |index| job(mk4, created_at: (10 - index).minutes.ago) }

      queue = run(query, first: 2)['printQueue']

      expect(queue['jobs'].pluck('id')).to eq(jobs.first(2).map { |queued| queued.id.to_s })
      expect(queue['totalCount']).to eq 4
    end

    it "lists one printer's queue when given its id" do
      job(mini, created_at: 2.hours.ago)
      mine = job(mk4, created_at: 1.hour.ago)

      queue = run(query, printerId: mk4.id.to_s, first: 10)['printQueue']

      expect(queue['jobs'].pluck('id')).to eq [mine.id.to_s]
      expect(queue['totalCount']).to eq 1
    end

    it 'breaks created_at ties by id, in the order the spooler starts them' do
      at = 1.hour.ago.change(usec: 0)
      first = job(mk4, created_at: at)
      second = job(mk4, created_at: at)

      queue = run(query, printerId: mk4.id.to_s, first: 10)['printQueue']

      expect(queue['jobs'].pluck('id')).to eq [first.id.to_s, second.id.to_s]
      expect(mk4.queue.to_a).to eq [first, second]
    end

    it 'counts the jobs without listing any for first: 0' do
      job(mk4)

      expect(run(query, first: 0)['printQueue']).to eq('totalCount' => 1, 'jobs' => [])
    end

    it 'is empty for a printer with nothing enqueued' do
      expect(run(query, printerId: mk4.id.to_s, first: 5)['printQueue']).to eq('totalCount' => 0, 'jobs' => [])
    end

    it 'refuses more than 50 rows, or a negative count' do
      [51, -1].each do |first|
        post '/graphql', params: { query:, variables: { first: }.to_json }

        expect(json['errors'].pluck('message')).to eq ['first must be within 0..50']
      end
    end

    it 'reads the jobs, their printers and their files in the same number of queries for 1 and 5 printers' do
      count = lambda do |printer_count|
        Printer::Job.delete_all
        Printer.delete_all
        printer_count.times { create(:printer).then { |printer| 2.times { job(printer) } } }
        sql_queries { run(query, first: 20) }.size
      end

      expect(count.call(5)).to eq count.call(1)
    end
  end

  describe 'jobHistory' do
    let(:query) do
      <<~GRAPHQL
        query($printerId: ID, $first: Int!) {
          jobHistory(printerId: $printerId, first: $first) {
            id status updatedAt executable { filename } printer { name }
          }
        }
      GRAPHQL
    end

    it 'lists the finished jobs, the last finished first, with their status as stored' do
      older = job(mk4, 'completed', created_at: 5.hours.ago, updated_at: 3.hours.ago)
      failed = job(mini, 'error', created_at: 2.hours.ago, updated_at: 40.minutes.ago)
      # Enqueued earlier, finished later: the finish time orders the history
      newer = job(mk4, 'completed', created_at: 6.hours.ago, updated_at: 1.hour.ago)
      job(mk4, 'enqueued')
      job(mk4, 'active')

      history = run(query, first: 10)['jobHistory']

      expect(history.pluck('id')).to eq([failed, newer, older].map { |finished| finished.id.to_s })
      expect(history.pluck('status')).to eq %w[error completed completed]
      expect(history.first).to include('executable' => { 'filename' => 'test.gcode' },
                                       'printer' => { 'name' => 'Prusa Mini+' },
                                       'updatedAt' => failed.updated_at.iso8601)
    end

    it "lists one printer's history, the first ones only" do
      job(mini, 'completed', updated_at: 1.minute.ago)
      mine = Array.new(3) { |index| job(mk4, 'completed', updated_at: (index + 2).minutes.ago) }

      history = run(query, printerId: mk4.id.to_s, first: 2)['jobHistory']

      expect(history.pluck('id')).to eq(mine.first(2).map { |finished| finished.id.to_s })
    end

    it 'refuses more than 50 rows' do
      post '/graphql', params: { query:, variables: { first: 51 }.to_json }

      expect(json['errors'].pluck('message')).to eq ['first must be within 0..50']
    end

    it 'reads the jobs, their printers and their files in the same number of queries for 1 and 5 printers' do
      count = lambda do |printer_count|
        Printer::Job.delete_all
        Printer.delete_all
        printer_count.times { create(:printer).then { |printer| 2.times { job(printer, 'completed') } } }
        sql_queries { run(query, first: 20) }.size
      end

      expect(count.call(5)).to eq count.call(1)
    end
  end
end
