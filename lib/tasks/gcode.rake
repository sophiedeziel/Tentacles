# frozen_string_literal: true

namespace :gcode do
  desc 'Read again the G-code files never read, or read by an older Gcode::Summary::VERSION (bump it first)'
  task reanalyse: :environment do
    count = Library::GcodeReanalysis.new.tap(&:save!).count
    puts "Enqueued AnalyseGcodeJob for #{count} #{'file'.pluralize(count)}"
  end
end
