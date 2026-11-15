# frozen_string_literal: true

module Types
  # The options of a ::PrinterWidget (missing ones read as their default)
  class PrinterWidgetOptions < Base::Object
    description "A Printer widget's options"
    default_broadcastable true

    field :camera, Boolean, null: false, description: 'Show the webcam'
    field :time_left, Boolean, null: false, description: 'Show the time left'
    field :temperatures, Boolean, null: false, description: 'Show the temperatures'
    field :up_next, Boolean, null: false, description: 'Show the next job of the queue'
    field :controls, Boolean, null: false, description: 'Show the pause, resume, cancel and connect controls'
  end
end
