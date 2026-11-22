# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationModel do
  let(:expected_error) { stub_const('ExpectedError', Class.new(StandardError)) }
  let(:model_class) do
    error_class = expected_error
    stub_const('Greeting', Class.new(described_class) do
      attribute :name, :string
      attribute :fail_with
      attr_reader :log

      validates :name, presence: true
      rescue_into_errors error_class

      before_save { (@log ||= []) << :before }
      after_save { @log << :after }

      private

      def persist
        raise fail_with if fail_with

        @log << :persist
      end
    end)
  end

  describe '#save!' do
    it 'validates, then persists inside the save callbacks' do
      model = model_class.new(name: 'Ada')

      expect(model.save!).to be(true)
      expect(model.log).to eq(%i[before persist after])
    end

    it 'runs the after_save callbacks even when #persist returns false' do
      model = model_class.new(name: 'Ada')
      allow(model).to receive(:persist).and_return(false)
      model.instance_variable_set(:@log, [])

      model.save!

      expect(model.log).to eq(%i[before after])
    end

    it 'raises ActiveModel::ValidationError when invalid, without persisting' do
      model = model_class.new

      expect { model.save! }.to raise_error(ActiveModel::ValidationError, /Name can't be blank/)
      expect(model.log).to be_nil
    end

    it 'lets the expected errors through' do
      model = model_class.new(name: 'Ada', fail_with: expected_error.new('Printer unreachable'))

      expect { model.save! }.to raise_error(expected_error, 'Printer unreachable')
    end

    it 'raises ReadOnlyRecord on a read-only model' do
      model = model_class.new(name: 'Ada')
      allow(model).to receive(:readonly?).and_return(true)

      expect { model.save! }.to raise_error(described_class::ReadOnlyRecord)
    end
  end

  describe '#save' do
    it 'returns true once persisted' do
      expect(model_class.new(name: 'Ada').save).to be(true)
    end

    it 'returns false with the validation errors when invalid' do
      model = model_class.new

      expect(model.save).to be(false)
      expect(model.errors.full_messages).to eq(["Name can't be blank"])
    end

    it 'returns false with the message in errors[:base] for an expected error' do
      model = model_class.new(name: 'Ada', fail_with: expected_error.new('Printer unreachable'))

      expect(model.save).to be(false)
      expect(model.errors[:base]).to eq(['Printer unreachable'])
    end

    it 'words the message with #error_message_for when the model overrides it' do
      worded = Class.new(model_class) do
        private

        def error_message_for(error) = "Could not greet: #{error.message}"
      end
      model = worded.new(name: 'Ada', fail_with: expected_error.new('Printer unreachable'))

      expect(model.save).to be(false)
      expect(model.errors[:base]).to eq(['Could not greet: Printer unreachable'])
    end

    it 'raises the other errors' do
      model = model_class.new(name: 'Ada', fail_with: ArgumentError.new('bug'))

      expect { model.save }.to raise_error(ArgumentError, 'bug')
    end
  end

  describe '.rescue_into_errors' do
    it "adds to the parent's list without changing it" do
      other_error = Class.new(StandardError)
      child = Class.new(model_class) { rescue_into_errors other_error }

      expect(child.expected_errors).to eq([expected_error, other_error])
      expect(model_class.expected_errors).to eq([expected_error])
    end
  end

  describe '#update and #update!' do
    it 'assigns the attributes, then saves' do
      model = model_class.new(name: 'Ada')

      expect(model.update(name: 'Grace')).to be(true)
      expect(model.name).to eq('Grace')
      expect(model.update(name: '')).to be(false)
      expect { model.update!(name: '') }.to raise_error(ActiveModel::ValidationError)
    end
  end

  describe '.create and .create!' do
    it 'builds and saves' do
      expect(model_class.create(name: 'Ada').log).to eq(%i[before persist after])
      expect(model_class.create(name: '').errors).to be_present
      expect { model_class.create!(name: '') }.to raise_error(ActiveModel::ValidationError)
    end
  end

  it 'refuses to save a model that has nothing to persist' do
    plain = stub_const('Plain', Class.new(described_class))

    expect { plain.new.save }.to raise_error(NotImplementedError, 'Plain has nothing to save')
  end
end
