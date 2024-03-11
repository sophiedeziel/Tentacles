require 'rails_helper'

RSpec.describe Label, type: :model do
  let(:label) { build(:label) }

  it 'has a valid factory' do
    expect(label).to be_valid
  end

  describe '#name' do
    subject { label.name }

    it { is_expected.to eq 'My red label' }
  end

  describe '#color' do
    subject { label.color }

    it { is_expected.to eq '#ff0000' }
  end

  it 'has a valid name' do
    expect(Label.new(name: nil, color: '#ffffff')).to_not be_valid
    expect(Label.new(name: '', color: '#ffffff')).to_not be_valid
    expect(Label.new(color: '#ffffff')).to_not be_valid
  end

  it 'has a unique name' do
    Label.create(name: 'My yellow label', color: '#0000ff') # same as create(:label, name: 'My yellow label', color: '#0000ff')
    duplicate_label = Label.new(name: 'My yellow label', color: '#00f')
    expect(duplicate_label).to_not be_valid
  end

  it 'has a valid color format' do
    expect(Label.new(name: 'my label')).to_not be_valid
    expect(Label.new(name: 'my label', color: '')).to_not be_valid
    expect(Label.new(name: 'my label', color: nil)).to_not be_valid
    expect(Label.new(name: 'my label', color: 'green')).to_not be_valid
    expect(Label.new(name: 'my label', color: '123456')).to_not be_valid
    expect(Label.new(name: 'my label', color: '#1234')).to_not be_valid
    expect(Label.new(name: 'my label', color: '#gg00gg')).to_not be_valid
    expect(Label.new(name: 'my label', color: 'rgb(0, 155, 0)')).to_not be_valid
    expect(Label.new(name: 'my label', color: '#ff00ff')).to be_valid
    expect(Label.new(name: 'my label', color: '#f0f')).to be_valid
  end
end
