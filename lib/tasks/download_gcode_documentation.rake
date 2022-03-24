# frozen_string_literal: true

require 'yaml'

namespace :gcode_documentation do
  desc 'TODO'
  task fetch: :environment do
    sh 'bin/download-gcode-docs'
    files = Dir.glob('tmp/MarlinDocumentation/_gcode/*.md')
    docs = {}
    files.each do |file|
      content = File
                .open(file)
                .flat_map(&:to_s)
                .to_a
                .slice_after(/^---/)
                .reject { |line| line[0].match?(/^---/) }
      parsed = YAML.safe_load(content.first.join)
      parsed['codes'].each do |code|
        docs[code] = {
          structuredDoc: parsed,
          mdDescription: content.last.join
        }
      end
    end
    File.write('app/ui/sections/Files/FileEditor/GcodeDocs/GcodeDocs.json', docs.to_json)
  end
end
