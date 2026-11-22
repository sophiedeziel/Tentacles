# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20261122120000_rename_stored_class_names_to_domain_namespaces')

RSpec.describe RenameStoredClassNamesToDomainNamespaces do
  let(:connection) { ActiveRecord::Base.connection }
  let(:migration) { described_class.new.tap { |migration| migration.verbose = false } }

  let(:printer) { create(:printer) }
  let(:section) { Dashboard::Section.create!(position: 0) }
  let!(:printer_widget) do
    Dashboard::PrinterWidget.create!(section:, printer:, width_units: 2, height_units: 1, position: 0)
  end
  let!(:queue_widget) { Dashboard::PrintQueueWidget.create!(section:, width_units: 4, height_units: 2, position: 1) }
  let!(:job) { create(:printer_job, printer:) }
  let(:item) { job.executable }

  # The class names as stored, read with SQL: the models only know the new names
  def stored_names
    {
      printer_widget: stored('dashboard_widgets', 'type', printer_widget.id),
      queue_widget: stored('dashboard_widgets', 'type', queue_widget.id),
      job: stored('printer_jobs', 'executable_type', job.id),
      attachment: stored('active_storage_attachments', 'record_type', item.file.attachment.id)
    }
  end

  def stored(table, column, id)
    connection.select_value("SELECT #{column} FROM #{table} WHERE id = #{Integer(id)}")
  end

  def store(table, column, id, value)
    connection.execute("UPDATE #{table} SET #{column} = #{connection.quote(value)} WHERE id = #{Integer(id)}")
  end

  describe '#up' do
    # As the previous release saved them
    before do
      store('dashboard_widgets', 'type', printer_widget.id, 'PrinterWidget')
      store('dashboard_widgets', 'type', queue_widget.id, 'PrintQueueWidget')
      store('printer_jobs', 'executable_type', job.id, 'FileRecord')
      store('active_storage_attachments', 'record_type', item.file.attachment.id, 'FileRecord')
      migration.up
    end

    it 'stores the namespaced class names' do
      expect(stored_names).to eq(printer_widget: 'Dashboard::PrinterWidget', queue_widget: 'Dashboard::PrintQueueWidget',
                                 job: 'Library::Item', attachment: 'Library::Item')
    end

    it 'loads the widgets, the job and the file through the renamed models' do
      expect(Dashboard::Widget.order(:position).to_a).to eq([printer_widget, queue_widget])
      expect(Dashboard::Widget.order(:position).map(&:class))
        .to eq([Dashboard::PrinterWidget, Dashboard::PrintQueueWidget])
      expect(Printer::Job.find(job.id).executable).to eq(item)
      expect(Library::Item.find(item.id).file).to be_attached
    end

    it 'leaves the other class names alone' do
      store('active_storage_attachments', 'record_type', item.file.attachment.id, 'Printer')
      migration.up

      expect(stored_names[:attachment]).to eq('Printer')
    end
  end

  describe '#down' do
    before { migration.down }

    it 'puts the class names back as the previous release had them' do
      expect(stored_names).to eq(printer_widget: 'PrinterWidget', queue_widget: 'PrintQueueWidget',
                                 job: 'FileRecord', attachment: 'FileRecord')
    end

    it 'can run up again' do
      migration.up

      expect(stored_names).to eq(printer_widget: 'Dashboard::PrinterWidget', queue_widget: 'Dashboard::PrintQueueWidget',
                                 job: 'Library::Item', attachment: 'Library::Item')
    end
  end
end
