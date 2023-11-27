# frozen_string_literal: true

module Types
  class GcodeAnalysis < Base::Object
    class Temperature < Base::Object
      field :temperature, Integer, null: false
      field :line_number, Integer, null: false
    end

    class ZMovements < Base::Object
      field :height, Float, null: false
      field :line_number, Integer, null: false
    end

    field :top_file_comments, [String], null: false
    field :slicer, String, null: true
    def slicer
      object.slicer.serialize
    end
    field :hotend_temperatures, [Types::GcodeAnalysis::Temperature], null: true
    field :bed_temperatures, [Types::GcodeAnalysis::Temperature], null: true
    field :z_movements, [Types::GcodeAnalysis::ZMovements], null: true
  end
end
