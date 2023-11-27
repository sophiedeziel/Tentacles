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

    class Layer < Base::Object
      field :id, Integer, null: false
      field :line_number, Integer, null: false
      field :height, Float, null: false
      field :z, Float, null: false
    end

    field :top_file_comments, [String], null: false
    field :slicer, String, null: true
    def slicer
      object.slicer.class.name
    end
    field :hotend_temperatures, [Temperature], null: true
    field :bed_temperatures, [Temperature], null: true
    field :z_movements, [ZMovements], null: true
    field :layers, [Layer], null: true
  end
end
