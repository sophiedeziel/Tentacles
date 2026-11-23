# typed: true
# frozen_string_literal: true

module Dashboard
  # A run of dashboard widgets. The section at position 0 holds the widgets above any divider and has no title; every
  # other section is a divider with a title. One global set of sections is the dashboard: no users, the last save wins.
  #
  #   Dashboard::Section.ensure_default!
  #   Dashboard::Section.includes(widgets: :printer).to_a # the layout, in order
  class Section < ApplicationRecord
    MAX_SECTIONS = 50
    MAX_WIDGETS = 200
    MAX_TITLE_LENGTH = 100
    # A MySQL named lock (per database: the names are global to the server), so that creating the default layout and
    # saving never run at the same time
    LOCK_NAME = 'dashboard_layout'
    LOCK_TIMEOUT = 10 # seconds

    # Raised by replace_all! with every problem found, as readable messages
    class InvalidLayout < StandardError
      attr_reader :messages

      def initialize(messages)
        @messages = messages
        super(messages.join('; '))
      end
    end

    # dashboard_section_id keeps its name from before the Dashboard namespace
    has_many :widgets, -> { order(:position) },
             class_name: 'Dashboard::Widget', foreign_key: :dashboard_section_id, inverse_of: :section,
             dependent: :destroy
    default_scope { order(:position) }

    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }, unless: :first?
    validate :first_section_untitled

    # Creates the default layout when there is none (on the first `dashboard` query)
    #: -> void
    def self.ensure_default!
      return if exists?

      with_layout_lock do
        create_default! unless exists? # another request may have created it while this one waited
      end
    end

    # The default layout, unsaved (no ids): one section with a Print Queue XL (4×2) for all printers, with one row per
    # printer and history on, then a Printer M (2×1) per printer with the camera off. Printers past the widget limit
    # are left out.
    #: -> Array[Dashboard::Section]
    def self.build_default
      printers = ::Printer.order(:id).limit(MAX_WIDGETS - 1).to_a
      widgets = printers.each_with_index.map do |printer, index|
        Dashboard::PrinterWidget.new(printer:, width_units: 2, height_units: 1, position: index + 1,
                                     options: { 'camera' => false })
      end
      section = new(title: nil, position: 0)
      queue = Dashboard::PrintQueueWidget.new(width_units: 4, height_units: 2, position: 0,
                                              options: { 'row_per_printer' => true, 'history' => true })
      section.widgets = [queue, *widgets]
      [section]
    end

    # Replaces the whole layout in one transaction: rows with an id are updated, rows without one are created, and rows
    # missing from `sections` are destroyed. Raises InvalidLayout. See Dashboard::Section::Replacement for the format.
    #: (Array[Hash[Symbol, untyped]] sections) -> void
    def self.replace_all!(sections)
      Replacement.new(sections).call
    end

    # rubocop:disable Naming/BlockForwarding -- Sorbet sigs need a named block
    #: { -> void } -> void
    def self.with_layout_lock(&block)
      name = connection.quote("#{connection.current_database}:#{LOCK_NAME}")
      locked = connection.select_value("SELECT GET_LOCK(#{name}, #{LOCK_TIMEOUT})") == 1
      raise ActiveRecord::LockWaitTimeout, 'Timed out waiting for the dashboard layout' unless locked

      yield
    ensure
      # Released even if an interruption hit before `locked` was set: releasing a lock not held is a no-op
      connection.select_value("SELECT RELEASE_LOCK(#{name})") if name
    end
    # rubocop:enable Naming/BlockForwarding

    # Built once more when a printer is deleted between build_default and the save
    #: -> void
    def self.create_default!
      attempts = 0
      begin
        attempts += 1
        transaction { build_default.each(&:save!) }
      rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey
        raise if attempts > 1

        retry
      end
    end
    private_class_method :create_default!

    #: -> bool
    def first?
      position == 0 # rubocop:disable Style/NumericPredicate -- position is nil on a new section
    end

    private

    def first_section_untitled
      errors.add(:title, 'must be empty for the first section') if first? && !title.nil?
    end
  end
end
