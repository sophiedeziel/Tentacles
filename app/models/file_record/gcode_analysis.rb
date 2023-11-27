class FileRecord
  class GcodeAnalysis
    attr_reader :hotend_temperatures, :bed_temperatures, :z_movements

    COMMAND_WATCHERS = {
      'M104' => :hotend_temperature_changes,
      'M140' => :bed_temperature_changes,
      'G1' => :z_movement_changes,
      'G0' => :z_movement_changes
    }.freeze

    def initialize(file_content)
      @hotend_temperatures = []
      @bed_temperatures = []
      @z_movements = []
      @layers = []
      analyze(file_content.split("\n"))
    end

    def analyze(file_content)
      file_content.each_with_index do |line, index|
        command = sanitize(line)
        parsed_command = parse(command)
        if COMMAND_WATCHERS[parsed_command[:command]]
          send(COMMAND_WATCHERS[parsed_command[:command]], parsed_command,
               index)
        end
      end
    end

    private

    def hotend_temperature_changes(command, index)
      @hotend_temperatures << { temperature: command.dig(:args, 'S').to_i, line_number: index + 1 }
    end

    def bed_temperature_changes(command, index)
      @bed_temperatures << { temperature: command.dig(:args, 'S').to_i, line_number: index + 1 }
    end

    def z_movement_changes(command, index)
      if command.dig(:args, 'Z')
        @z_movement_extrusion_unchecked = { z: command.dig(:args, 'Z').to_f, line_number: index + 1 }
      end
      puts command if index < 32
      return unless command.dig(:args, 'E').present? && @z_movement_extrusion_unchecked.present?

      @z_movements << @z_movement_extrusion_unchecked
      @z_movement_extrusion_unchecked = nil
    end

    def sanitize(line)
      line.split(';').first
    end

    def parse(line)
      tokens = line.split(' ')
      arguments = {}
      tokens[1..]&.each do |argument|
        argument_name = argument[0]
        argument_value = argument[1..]
        arguments[argument_name] = argument_value
      end
      { command: tokens.first, args: arguments }
    end
  end
end
