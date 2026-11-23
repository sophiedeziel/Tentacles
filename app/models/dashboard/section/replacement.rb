# typed: true
# frozen_string_literal: true

module Dashboard
  class Section
    # Replaces the whole layout with a tree of attributes (Dashboard::Section.replace_all!):
    #
    #   [{ id:, title:, widgets: [
    #     { id:, type: 'Dashboard::PrinterWidget', width_units:, height_units:, printer_id:, options: {} }
    #   ] }]
    #
    # Positions come from the order. An id that no longer exists (deleted by another save) creates a new row, so the
    # last save still wins. Every problem is reported at once, prefixed with where it is ("Widget 2 in section 1: ...").
    class Replacement
      #: (Array[Hash[Symbol, untyped]] sections) -> void
      def initialize(sections)
        @sections = sections
        @errors = [] #: Array[String]
      end

      # Raises InvalidLayout before loading anything when the layout is over a limit
      #: (Array[Hash[Symbol, untyped]] sections) -> void
      def self.check_limits!(sections)
        widget_count = sections.sum { |section| Array(section[:widgets]).size }
        errors = []
        errors << 'A layout needs at least one section' if sections.empty?
        errors << "A layout can't have more than #{MAX_SECTIONS} sections" if sections.size > MAX_SECTIONS
        errors << "A layout can't have more than #{MAX_WIDGETS} widgets" if widget_count > MAX_WIDGETS
        raise InvalidLayout, errors if errors.any?
      end

      #: -> void
      def call
        self.class.check_limits!(@sections)
        Dashboard::Section.with_layout_lock do
          Dashboard::Section.transaction do
            load_existing
            sections, widgets = build
            raise InvalidLayout, @errors if @errors.any?

            save(sections, widgets)
          end
        end
      end

      private

      # Whatever is still in these hashes after #build is destroyed
      def load_existing
        @existing_sections = Dashboard::Section.unscoped.lock.index_by(&:id)
        @existing_widgets = Dashboard::Widget.lock.index_by(&:id)
        printer_ids = @sections.flat_map { |section| Array(section[:widgets]).pluck(:printer_id) }
        # Shared locks: a printer can't be deleted before its widgets are saved
        @printers = ::Printer.where(id: printer_ids.filter_map { |id| integer_id(id) }).lock('FOR SHARE').index_by(&:id)
      end

      def build
        widgets = []
        sections = @sections.each_with_index.map { |attributes, index| build_section(attributes, index, widgets) }
        [sections, widgets.compact]
      end

      def build_section(attributes, index, widgets)
        section = @existing_sections.delete(integer_id(attributes[:id])) || Dashboard::Section.new
        section.assign_attributes(title: attributes[:title], position: index)
        collect_errors(section, "Section #{index + 1}")
        Array(attributes[:widgets]).each_with_index do |widget, position|
          label = "Widget #{position + 1} in section #{index + 1}"
          widgets << build_widget(attributes: widget, section:, position:, label:)
        end
        section
      end

      def build_widget(attributes:, section:, position:, label:)
        widget = find_or_build_widget(attributes:, label:)
        return unless widget

        widget.assign_attributes(section:, position:, printer: printer(attributes:, label:),
                                 width_units: attributes[:width_units], height_units: attributes[:height_units],
                                 options: attributes[:options].to_h.transform_keys(&:to_s))
        collect_errors(widget, label)
        widget
      end

      # A widget keeps its row unless its type changed
      def find_or_build_widget(attributes:, label:)
        type = attributes[:type]
        unless Dashboard::Widget::TYPES.include?(type)
          @errors << "#{label}: unknown type"
          return
        end

        id = integer_id(attributes[:id])
        @existing_widgets[id]&.type == type ? @existing_widgets.delete(id) : type.constantize.new
      end

      def printer(attributes:, label:)
        return if attributes[:printer_id].nil?

        printer = @printers[integer_id(attributes[:printer_id])]
        @errors << "#{label}: printer doesn't exist" unless printer
        printer
      end

      def collect_errors(record, label)
        return if record.valid?

        record.errors.full_messages.each do |message|
          @errors << "#{label}: #{message}" unless message == 'Section must exist'
        end
      end

      def save(sections, widgets)
        sections.each(&:save!)
        widgets.each(&:save!)
        @existing_widgets.each_value(&:destroy!)
        @existing_sections.each_value(&:destroy!)
        # The layout's updatedAt, also after a removal. Touching skips validations on purpose.
        Dashboard::Section.unscoped.touch_all # rubocop:disable Rails/SkipsModelValidations
      end

      def integer_id(id)
        id.is_a?(Integer) ? id : Integer(id.to_s, 10, exception: false)
      end
    end
  end
end
