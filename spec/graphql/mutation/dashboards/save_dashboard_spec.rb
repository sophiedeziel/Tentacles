# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::Dashboards::SaveDashboard, type: :request do
  let(:mutation) do
    <<~GRAPHQL
      mutation($sections: [DashboardSectionInput!]!) {
        saveDashboard(input: { sections: $sections }) {
          errors
          dashboard {
            updatedAt
            sections {
              id
              title
              widgets {
                id
                type
                widthUnits
                heightUnits
                printer { id }
                options {
                  ... on PrinterWidgetOptions { camera timeLeft temperatures upNext controls }
                  ... on PrintQueueWidgetOptions { nowPrinting startNext rowPerPrinter history }
                }
              }
            }
          }
        }
      }
    GRAPHQL
  end
  let(:printer) { create(:printer, name: 'Prusa MK4') }
  let(:sections) do
    [
      { id: nil, title: nil, widgets: [
        { id: nil, type: 'PRINT_QUEUE', widthUnits: 4, heightUnits: 4, printerId: nil,
          options: { printQueue: { history: true, startNext: false } } }
      ] },
      { id: nil, title: 'Garage', widgets: [
        { id: nil, type: 'PRINTER', widthUnits: 1, heightUnits: 1, printerId: printer.id.to_s,
          options: { printer: { camera: false } } }
      ] }
    ]
  end
  let(:result) { response.parsed_body.dig('data', 'saveDashboard') }

  before { allow(TentaclesSchema.subscriptions).to receive(:trigger) }

  def save(sections)
    post '/graphql', params: { query: mutation, variables: { sections: } }, as: :json
    expect(response.parsed_body['errors']).to be_nil
  end

  it 'saves the tree and returns it with the new ids' do
    save(sections)

    garage = Dashboard::Section.find_by!(title: 'Garage')
    expect(result['errors']).to eq([])
    expect(result['dashboard']).to eq(
      'updatedAt' => garage.updated_at.utc.iso8601,
      'sections' => [
        { 'id' => Dashboard::Section.first.id.to_s, 'title' => nil, 'widgets' => [
          { 'id' => Dashboard::PrintQueueWidget.sole.id.to_s, 'type' => 'PRINT_QUEUE', 'widthUnits' => 4,
            'heightUnits' => 4, 'printer' => nil,
            'options' => { 'nowPrinting' => true, 'startNext' => false, 'rowPerPrinter' => false, 'history' => true } }
        ] },
        { 'id' => garage.id.to_s, 'title' => 'Garage', 'widgets' => [
          { 'id' => Dashboard::PrinterWidget.sole.id.to_s, 'type' => 'PRINTER', 'widthUnits' => 1, 'heightUnits' => 1,
            'printer' => { 'id' => printer.id.to_s },
            'options' => { 'camera' => false, 'timeLeft' => true, 'temperatures' => true, 'upNext' => true,
                           'controls' => true } }
        ] }
      ]
    )
  end

  it 'stores only the options sent' do
    save(sections)

    expect(Dashboard::PrintQueueWidget.sole.options).to eq('history' => true, 'start_next' => false)
    expect(Dashboard::PrinterWidget.sole.options).to eq('camera' => false)
  end

  it 'updates rows sent with their id and destroys the missing ones' do
    save(sections)
    saved = result['dashboard']['sections']
    queue = saved.first['widgets'].first

    save([{ id: saved.last['id'], title: nil, widgets: [
           { id: queue['id'], type: 'PRINT_QUEUE', widthUnits: 2, heightUnits: 1, printerId: printer.id.to_s,
             options: { printQueue: {} } }
         ] }])

    expect(result['errors']).to eq([])
    expect(Dashboard::Section.sole.id.to_s).to eq(saved.last['id'])
    expect(Dashboard::Widget.sole).to have_attributes(id: queue['id'].to_i, width_units: 2, printer:, options: {})
  end

  it 'triggers dashboardChanged' do
    save(sections)

    expect(TentaclesSchema.subscriptions).to have_received(:trigger).with(:dashboard_changed, {}, {}).once
  end

  context 'with an invalid layout' do
    before do
      sections.last[:widgets].first.merge!(widthUnits: 4, heightUnits: 4, printerId: '0')
      sections.last[:title] = ' '
    end

    it 'returns every error, saves nothing and triggers nothing' do
      save(sections)

      expect(result).to eq(
        'dashboard' => nil,
        'errors' => ["Section 2: Title can't be blank",
                     "Widget 1 in section 2: printer doesn't exist",
                     "Widget 1 in section 2: 4×4 isn't a size this widget supports",
                     "Widget 1 in section 2: Printer can't be blank"]
      )
      expect(Dashboard::Section.count).to eq(0)
      expect(TentaclesSchema.subscriptions).not_to have_received(:trigger)
    end
  end

  it "refuses options that don't match the widget's type" do
    sections.last[:widgets].first[:options] = { printQueue: { history: true } }
    save(sections)

    expect(result['errors']).to eq(["Widget 1 in section 2: options don't match the widget type"])
    expect(Dashboard::Section.count).to eq(0)
  end

  it 'refuses more than 200 widgets, before checking each one' do
    sections.first[:widgets] = [sections.last[:widgets].first.merge(options: { printQueue: {} })] * 201
    save(sections)

    expect(result['errors']).to eq(["A layout can't have more than 200 widgets"])
  end

  [ActiveRecord::LockWaitTimeout, ActiveRecord::Deadlocked, ActiveRecord::InvalidForeignKey].each do |error|
    it "returns a retry message on #{error.name.demodulize}" do
      allow(Dashboard::Section).to receive(:replace_all!).and_raise(error)
      save(sections)

      expect(result).to eq('dashboard' => nil, 'errors' => ['The dashboard changed while saving, try again'])
    end
  end

  it 'still returns the saved layout when the push fails' do
    allow(TentaclesSchema.subscriptions).to receive(:trigger).and_raise(Redis::CannotConnectError)
    save(sections)

    expect(result['errors']).to eq([])
    expect(Dashboard::Section.count).to eq(2)
  end

  describe 'the options input (one_of)' do
    def graphql_errors(options)
      sections.last[:widgets].first[:options] = options
      post '/graphql', params: { query: mutation, variables: { sections: } }, as: :json
      response.parsed_body['errors'].pluck('message')
    end

    it 'refuses both printer and printQueue options, or none' do
      expect(graphql_errors({ printer: {}, printQueue: {} })).to include(/requires exactly one argument/)
      expect(graphql_errors({})).to include(/requires exactly one argument/)
      expect(Dashboard::Section.count).to eq(0)
    end
  end
end
