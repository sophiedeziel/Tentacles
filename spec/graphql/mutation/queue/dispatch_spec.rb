# frozen_string_literal: true

require 'rails_helper'
require_relative 'queue_mutation_context'

RSpec.describe 'Mutations pauseDispatch and resumeDispatch', type: :request do
  include_context 'with a queue mutation'

  def pause = mutate('pauseDispatch', {}, 'globalQueue { dispatchPaused }')
  def resume = mutate('resumeDispatch', {}, 'globalQueue { dispatchPaused }')

  it 'pauses dispatch and returns the queue' do
    pause

    expect_saved
    expect(data['globalQueue']).to eq('dispatchPaused' => true)
    expect(PrintQueue::Setting.dispatch_paused?).to be true
    expect(dispatch_request).not_to have_received(:save)
  end

  it 'resumes dispatch, returns the queue and asks for a dispatch pass' do
    PrintQueue::Setting.current.update!(dispatch_paused: true)

    resume

    expect_saved
    expect(data['globalQueue']).to eq('dispatchPaused' => false)
    expect(PrintQueue::Setting.dispatch_paused?).to be false
    expect(dispatch_request).to have_received(:save).once
  end

  it 'refuses to pause while the global queue is off' do
    turn_queue_off

    pause

    expect_refused('The global print queue is off')
    expect(data['globalQueue']).to be_nil
    expect(PrintQueue::Setting.dispatch_paused?).to be false
  end

  it 'refuses to resume while the global queue is off' do
    PrintQueue::Setting.current.update!(dispatch_paused: true)
    turn_queue_off

    resume

    expect_refused('The global print queue is off')
    expect(PrintQueue::Setting.dispatch_paused?).to be true
    expect_nothing_pushed
  end

  it 'returns a refusal when the queue is busy' do
    allow(PrintQueue::Setting).to receive(:lock_current).and_raise(ActiveRecord::LockWaitTimeout)

    pause

    expect_refused('The queue is busy, try again')
  end
end
