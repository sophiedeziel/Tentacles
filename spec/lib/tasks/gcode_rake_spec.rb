# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'gcode:reanalyse' do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?('gcode:reanalyse') }

  after { Rake::Task['gcode:reanalyse'].reenable }

  it 'schedules the outdated G-code files, and says how many' do
    create(:gcode_summary, :ready, analysis_version: Gcode::Summary::VERSION - 1)

    expect { Rake::Task['gcode:reanalyse'].invoke }
      .to output("Enqueued AnalyseGcodeJob for 1 file\n").to_stdout.and have_enqueued_job(AnalyseGcodeJob).once
  end
end
