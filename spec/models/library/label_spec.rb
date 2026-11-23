# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Library::Label, type: :model do
  it 'has a unique name' do
    Library::Label.create(name: 'My yellow label', color: '#0000ff')
    duplicate_label = Library::Label.new(name: 'My yellow label', color: '#00f')
    expect(duplicate_label).to_not be_valid
  end

  it 'has a valid color format' do
    expect(Library::Label.new(name: 'my label')).to_not be_valid
    expect(Library::Label.new(name: 'my label', color: '')).to_not be_valid
    expect(Library::Label.new(name: 'my label', color: nil)).to_not be_valid
    expect(Library::Label.new(name: 'my label', color: 'green')).to_not be_valid
    expect(Library::Label.new(name: 'my label', color: '123456')).to_not be_valid
    expect(Library::Label.new(name: 'my label', color: '#1234')).to_not be_valid
    expect(Library::Label.new(name: 'my label', color: '#gg00gg')).to_not be_valid
    expect(Library::Label.new(name: 'my label', color: 'rgb(0, 155, 0)')).to_not be_valid
    expect(Library::Label.new(name: 'my label', color: '#ff00ff')).to be_valid
    expect(Library::Label.new(name: 'my label', color: '#f0f')).to be_valid
  end
end
