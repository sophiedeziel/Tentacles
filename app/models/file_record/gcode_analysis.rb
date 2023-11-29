# frozen_string_literal: true

class FileRecord
  class GcodeAnalysis
    attr_reader :hotend_temperatures, :bed_temperatures, :z_movements, :top_file_comments, :slicer, :layers

    COMMAND_WATCHERS = {
      'M104' => :hotend_temperature_changes,
      'M140' => :bed_temperature_changes,
      'G1' => :z_movement_changes,
      'G0' => :z_movement_changes
    }.freeze

    def initialize(file)
      @file = file
      @hotend_temperatures = []
      @bed_temperatures = []
      @z_movements = []
      @layers = []
      analyze!
    end

    def analyze!
      @top_file_comments = find_top_file_comments
      @slicer = find_slicer

      each_line do |line, index|
        parsed_command = parse(line)
        check_line(parsed_command, index)
      end
    end

    def find_top_file_comments
      top_comments = []
      each_line do |line, _index|
        line.strip!
        return top_comments unless line.empty? || line.starts_with?(';')

        top_comments << line
      end
      top_comments
    end

    private

    def check_line(parsed_command, index)
      command = parsed_command[:command]

      @slicer&.analyse_comment(parsed_command[:comment], index)

      send(COMMAND_WATCHERS[command], parsed_command, index) if command.present? && COMMAND_WATCHERS[command]
    end

    def hotend_temperature_changes(command, index)
      @hotend_temperatures << { temperature: command.dig(:args, 'S').to_i, line_number: index + 1,
                                layer_number: @layers.last&.dig(:id) }
    end

    def bed_temperature_changes(command, index)
      @bed_temperatures << { temperature: command.dig(:args, 'S').to_i, line_number: index + 1,
                             layer_number: @layers.last&.dig(:id) }
    end

    def z_movement_changes(command, index)
      if command.dig(:args, 'Z')
        @z_movement_extrusion_unchecked = { height: command.dig(:args, 'Z').to_f, line_number: index + 1 }
      end

      return unless command.dig(:args, 'E').present? && @z_movement_extrusion_unchecked.present?

      @z_movements << @z_movement_extrusion_unchecked
      @z_movement_extrusion_unchecked = nil
    end

    def parse(line)
      command, comment = line.split(';')
      return { comment: } if command.blank?

      tokens = command.split
      args = {}
      tokens[1..]&.each do |argument|
        argument_name = argument[0]
        argument_value = argument[1..]
        args[argument_name] = argument_value
      end
      { command: tokens.first, args:, comment: }
    end

    def find_slicer
      Slicer.detect(self)
    end

    def each_line(&)
      @file.blob.open do |file|
        file.each_with_index(&)
      end
    end
  end
end
