# typed: true
# frozen_string_literal: true

# A tile of the dashboard. STI: each widget type is a subclass (PrinterWidget, PrintQueueWidget) that declares its
# options and the spans (grid columns × rows) it supports. S to XXL are only UI names for those spans.
#
# Options are JSON so that a new option or widget type needs no migration: missing keys read as the default.
# They persist for every size, so shrinking to S hides the camera but keeps `camera: true`.
class DashboardWidget < ApplicationRecord
  extend T::Sig

  # The widget types, as stored in `type`
  TYPES = %w[PrinterWidget PrintQueueWidget].freeze

  belongs_to :dashboard_section
  belongs_to :printer, optional: true

  validates :type, inclusion: { in: TYPES }
  validates :width_units, :height_units, numericality: { only_integer: true, in: 1..4 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :span_is_allowed
  validate :options_are_known, :options_are_booleans

  attribute :options, :json, default: -> { {} } # MySQL json can't take a literal default

  class_attribute :option_defaults, default: {}
  class_attribute :allowed_spans, default: [] # [[width, height], …]

  BOOLEAN = ActiveModel::Type::Boolean.new

  sig { params(spans: [Integer, Integer]).void }
  def self.widget_spans(*spans)
    self.allowed_spans = spans
  end

  # Declares a type's options: typed readers and writers over the json column
  sig { params(defaults: T::Boolean).void }
  def self.widget_options(**defaults)
    self.option_defaults = defaults
    defaults.each do |key, default|
      define_method(key) { BOOLEAN.cast(T.bind(self, DashboardWidget).options.fetch(key.to_s, default)) }
      define_method("#{key}=") { |value| T.bind(self, DashboardWidget).options[key.to_s] = BOOLEAN.cast(value) }
    end
  end

  private

  def span_is_allowed
    return if allowed_spans.include?([width_units, height_units])

    errors.add(:base, "#{width_units}×#{height_units} isn't a size this widget supports")
  end

  def options_are_known
    return errors.add(:options, 'must be an object') unless options.is_a?(Hash)

    unknown = options.keys - option_defaults.keys.map(&:to_s)
    errors.add(:options, "unknown: #{unknown.join(', ')}") if unknown.any?
  end

  # Options are booleans in v1
  def options_are_booleans
    return unless options.is_a?(Hash)

    declared = options.keys & option_defaults.keys.map(&:to_s)
    not_boolean = declared.reject { |key| [true, false].include?(options[key]) }
    errors.add(:options, "must be true or false: #{not_boolean.join(', ')}") if not_boolean.any?
  end
end
