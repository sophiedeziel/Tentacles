# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query dashboard and defaultDashboard', type: :request do
  let(:dashboard_fields) do
    <<~GRAPHQL
      updatedAt
      sections {
        id
        title
        widgets {
          id
          type
          widthUnits
          heightUnits
          printer { id name }
          options {
            __typename
            ... on PrinterWidgetOptions { camera timeLeft temperatures upNext controls }
            ... on PrintQueueWidgetOptions { nowPrinting startNext rowPerPrinter history }
          }
        }
      }
    GRAPHQL
  end
  let!(:printer) { create(:printer, name: 'Prusa MK4') }

  def run_query(field)
    post '/graphql', params: { query: "query { #{field} { #{dashboard_fields} } }" }, as: :json
    expect(response.parsed_body['errors']).to be_nil
    response.parsed_body.dig('data', field)
  end

  def default_widgets(ids: true)
    [
      { 'id' => ids ? be_present : nil, 'type' => 'PRINT_QUEUE', 'widthUnits' => 4, 'heightUnits' => 2,
        'printer' => nil,
        'options' => { '__typename' => 'PrintQueueWidgetOptions', 'nowPrinting' => true, 'startNext' => true,
                       'rowPerPrinter' => true, 'history' => true } },
      { 'id' => ids ? be_present : nil, 'type' => 'PRINTER', 'widthUnits' => 2, 'heightUnits' => 1,
        'printer' => { 'id' => printer.id.to_s, 'name' => 'Prusa MK4' },
        'options' => { '__typename' => 'PrinterWidgetOptions', 'camera' => false, 'timeLeft' => true,
                       'temperatures' => true, 'upNext' => true, 'controls' => true } }
    ]
  end

  describe 'dashboard' do
    it 'creates the default layout the first time' do
      dashboard = nil
      expect { dashboard = run_query('dashboard') }.to change(DashboardSection, :count).from(0).to(1)

      section = DashboardSection.sole
      expect(dashboard).to match(
        'updatedAt' => section.updated_at.utc.iso8601,
        'sections' => [{ 'id' => section.id.to_s, 'title' => nil, 'widgets' => default_widgets }]
      )
    end

    it 'returns the saved layout, with its dividers, in order' do
      garage = DashboardSection.create!(position: 1, title: 'Garage')
      top = DashboardSection.create!(position: 0)
      PrintQueueWidget.create!(dashboard_section: garage, printer:, width_units: 4, height_units: 4, position: 1,
                               options: { 'history' => true })
      PrinterWidget.create!(dashboard_section: garage, printer:, width_units: 1, height_units: 1, position: 0)

      sections = run_query('dashboard')['sections']

      expect(sections.map { |section| [section['id'], section['title']] })
        .to eq([[top.id.to_s, nil], [garage.id.to_s, 'Garage']])
      expect(sections.last['widgets'].map { |widget| widget.values_at('type', 'widthUnits', 'heightUnits') })
        .to eq([['PRINTER', 1, 1], ['PRINT_QUEUE', 4, 4]])
      expect(sections.last['widgets'].last).to include(
        'printer' => { 'id' => printer.id.to_s, 'name' => 'Prusa MK4' },
        'options' => include('history' => true, 'rowPerPrinter' => false)
      )
    end

    it "drops a deleted printer's widgets" do
      run_query('dashboard')
      printer.destroy!

      expect(run_query('dashboard')['sections'].first['widgets'].pluck('type')).to eq(['PRINT_QUEUE'])
    end

    it 'loads the layout and its printers in a fixed number of queries' do
      create_list(:printer, 5)
      run_query('dashboard')

      queries = []
      callback = ->(*_args, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { run_query('dashboard') }

      expect(queries.grep(/FROM `printers`/).size).to eq(1)
      expect(queries.grep(/FROM `dashboard_widgets`/).size).to eq(1)
    end
  end

  describe 'defaultDashboard' do
    it 'returns the default layout without saving it' do
      dashboard = nil
      expect { dashboard = run_query('defaultDashboard') }.not_to change(DashboardSection, :count)

      expect(dashboard).to match(
        'updatedAt' => nil,
        'sections' => [{ 'id' => nil, 'title' => nil, 'widgets' => default_widgets(ids: false) }]
      )
    end

    it 'ignores the saved layout' do
      DashboardSection.create!(position: 0)

      expect(run_query('defaultDashboard')['sections'].first['widgets']).to match(default_widgets(ids: false))
    end
  end
end
