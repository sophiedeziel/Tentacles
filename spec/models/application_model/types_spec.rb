# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApplicationModel attribute types' do
  let(:part_class) do
    stub_const('Part', Class.new(ApplicationModel) do
      attribute :name, :string

      define_method(:as_json) { |*_options| { 'name' => name } }
    end)
  end
  let(:model_class) do
    part = part_class
    Class.new(ApplicationModel) do
      attribute :family, ApplicationModel::EnumType.new(Printer::StateFamily)
      attribute :part, ApplicationModel::ModelType.new(part)
      attribute :at, ApplicationModel::TimeType.new
      attribute :tags, ApplicationModel::ArrayType.new(:string)
    end
  end

  def type(name) = model_class.attribute_types.fetch(name.to_s)

  describe ApplicationModel::EnumType do
    it 'casts the serialized value to the enum, and serializes it back' do
      model = model_class.new(family: 'PAUSED')

      expect(model.family).to eq Printer::StateFamily::Paused
      expect(type(:family).serialize(model.family)).to eq 'PAUSED'
    end

    it 'keeps enums and nil' do
      expect(model_class.new(family: Printer::StateFamily::Error).family).to eq Printer::StateFamily::Error
      expect(model_class.new(family: nil).family).to be_nil
    end

    it 'raises for an unknown value, when read' do
      expect { model_class.new(family: 'NAPPING').family }.to raise_error(KeyError)
    end

    it 'tells enums apart' do
      expect(described_class.new(Printer::StateFamily)).not_to eq described_class.new(TemperatureUnit)
    end
  end

  describe ApplicationModel::ModelType do
    it 'builds the model from a hash, ignoring the keys that are not attributes' do
      part = model_class.new(part: { name: 'hotend', removed: true }).part

      expect(part).to have_attributes(class: part_class, name: 'hotend')
    end

    it 'keeps models and serializes them as their JSON' do
      part = part_class.new(name: 'bed')
      model = model_class.new(part:)

      expect(model.part).to be part
      expect(type(:part).serialize(part)).to eq('name' => 'bed')
    end

    it 'raises for anything else, when read' do
      expect { model_class.new(part: 'bed').part }.to raise_error(ArgumentError, "Can't cast String to Part")
    end
  end

  describe ApplicationModel::TimeType do
    it 'casts ISO 8601 strings and epoch seconds to TimeWithZone' do
      iso = model_class.new(at: '2026-11-15T12:00:00.123Z').at
      epoch = model_class.new(at: 1_794_744_000.5).at

      expect([iso, epoch]).to all(be_a(ActiveSupport::TimeWithZone))
      expect(iso).to eq Time.utc(2026, 11, 15, 12, 0, 0, 123_000)
      expect(epoch.to_f).to eq 1_794_744_000.5
    end

    it 'serializes as ISO 8601 in UTC, to the millisecond' do
      time = Time.find_zone('America/Toronto').local(2026, 11, 15, 7, 0, 0.123456r)

      expect(type(:at).serialize(time)).to eq '2026-11-15T12:00:00.123Z'
    end
  end

  describe ApplicationModel::ArrayType do
    it 'casts each element to the element type' do
      expect(model_class.new(tags: ['PLA', :PETG, 3]).tags).to eq %w[PLA PETG 3]
    end

    it 'wraps a single value and keeps nil' do
      expect(model_class.new(tags: 'PLA').tags).to eq ['PLA']
      expect(model_class.new(tags: nil).tags).to be_nil
    end

    it 'serializes each element' do
      expect(type(:tags).serialize(%w[PLA PETG])).to eq %w[PLA PETG]
      expect(type(:tags).serialize(nil)).to be_nil
    end

    it 'tells element types apart' do
      expect(described_class.new(:string)).to eq described_class.new(:string)
      expect(described_class.new(:string)).not_to eq described_class.new(:integer)
    end
  end
end
