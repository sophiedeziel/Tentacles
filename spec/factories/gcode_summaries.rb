# frozen_string_literal: true

FactoryBot.define do
  factory :gcode_summary, class: 'Library::GcodeSummary' do
    item factory: :file_record

    trait :ready do
      status { 'ready' }
      analysis_version { Gcode::Summary::VERSION }
      analysed_at { Time.current }
      slicer { 'PrusaSlicer' }
      slicer_version { '2.9.6' }
      print_seconds { 1828 }
      min_x { 2 }
      max_x { 125.09 }
      min_y { 10 }
      max_y { 140 }
      max_z { 15 }
      footprint_source { 'moves' }
      tool_count { 1 }
      tool_changes { 0 }
    end

    trait :failed do
      status { 'failed' }
      error { 'Could not read the file' }
    end

    # One Tool row per material, from T0: `create(:gcode_summary, :ready, :with_tools, materials: ['PLA', nil])`
    trait :with_tools do
      transient do
        materials { ['PLA'] }
      end

      tool_count { materials.size }

      after(:create) do |summary, evaluator|
        evaluator.materials.each_with_index do |material, tool|
          create(:gcode_summary_tool, gcode_summary: summary, tool:, material:, material_raw: material || 'PCTG')
        end
        summary.tools.reset
      end
    end
  end

  factory :gcode_summary_tool, class: 'Library::GcodeSummary::Tool' do
    gcode_summary
    sequence(:tool) { |n| n - 1 }
    material { 'PLA' }
    material_raw { 'PLA' }
    colour_hex { '#DDDDDD' }
    grams { 2.63 }
    millimetres { 882.3 }
  end
end
