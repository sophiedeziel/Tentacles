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
<<<<<<< HEAD
      parsed = YAML.safe_load(content.first.join)
      parsed['codes'].each do |code|
        docs[code] = {
          structured_doc: parsed,
          md_description: content.last.join
        }
      end
    end
    File.write('app/ui/sections/Files/FileEditor/GcodeDocs/GcodeDocs.json', docs.to_json)
=======
      parsed = YAML.load(content.first.join)
      parsed["codes"].each do |code|
        docs[code] = {
          structured_doc: parsed,
          md_description: content.last.join
        } 
      end
    end
    File.open('app/ui/sections/Files/FileEditor/GcodeDocs/GcodeDocs.json', 'w') do |file|
      file.write(docs.to_json)
    end
>>>>>>> f3de111 (import transform gcode's documentation)
  end
end
