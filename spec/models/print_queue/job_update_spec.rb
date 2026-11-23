# frozen_string_literal: true

require 'rails_helper'
require_relative 'operation_shared_context'

RSpec.describe PrintQueue::JobUpdate do
  include_context 'with a queue operation'

  let(:job) { create(:print_job, copies: 5, position: 2, colour: 'Black') }
  let(:voron) { create(:printer, name: 'Voron 2.4') }
  let(:mk4) { create(:printer, name: 'Prusa MK4') }

  before { create(:gcode_summary, :ready, :with_tools, item: job.item, materials: ['PLA']) }

  def copy(status) = create(:printer_job, :copy, print_job: job, status:, printer: create(:printer))

  # The whole form, as the Edit page sends it
  def update(**attributes)
    described_class.new(job:, copies: 5, **attributes).tap(&:save)
  end

  it_behaves_like 'a queue operation' do
    let(:operation) { described_class.new(job:, copies: 6) }
  end

  it 'sets every option, pushes once and asks for a dispatch pass' do
    update = update(copies: 7, material: 'petg', colour: 'Grey', same_printer: true, all_capable: false,
                    printer_ids: [voron.id])

    expect(update.errors).to be_empty
    expect(job.reload).to have_attributes(copies: 7, material: 'PETG', colour: 'Grey', colour_key: 'grey',
                                          same_printer: true, all_capable: false, printers: [voron], position: 2,
                                          held: false)
    expect_pushed_once([])
    expect_dispatch_requested
  end

  it "takes the defaults for the options not given: the G-code's material, Any colour, every printer" do
    job.update!(material: 'PETG', same_printer: true, all_capable: false, printers: [voron])

    update

    expect(job.reload).to have_attributes(material: nil, colour: nil, same_printer: false, all_capable: true,
                                          printers: [])
  end

  it 'keeps its place and its hold (movePrintJob and holdPrintJob change them)' do
    job.update!(held: true)

    update(copies: 3)

    expect(job.reload).to have_attributes(position: 2, held: true, copies: 3)
  end

  describe 'a bound batch' do
    before { job.update!(same_printer: true, bound_printer: mk4) }

    it 'stays bound while same printer is on and its printer allowed' do
      update(same_printer: true, all_capable: false, printer_ids: [mk4.id, voron.id])

      expect(job.reload.bound_printer).to eq mk4
      expect_pushed_once([mk4])
    end

    it 'is let go when same printer goes off' do
      update(same_printer: false)

      expect(job.reload).to have_attributes(same_printer: false, bound_printer: nil)
      expect_pushed_once([mk4])
    end

    it 'is let go when its printer is no longer allowed' do
      update(same_printer: true, all_capable: false, printer_ids: [voron.id])

      expect(job.reload).to have_attributes(same_printer: true, bound_printer: nil)
    end
  end

  describe 'same printer turned on' do
    it 'binds the batch to the printer its copy is printing on, and pushes it' do
      printing = create(:printer_job, :copy, print_job: job, status: 'active', printer: mk4)

      update(same_printer: true)

      expect(job.reload).to have_attributes(same_printer: true, bound_printer: printing.printer)
      expect_pushed_once([mk4])
    end

    it 'leaves it unbound when that printer is not among the printers chosen' do
      create(:printer_job, :copy, print_job: job, status: 'active', printer: mk4)

      update(same_printer: true, all_capable: false, printer_ids: [voron.id])

      expect(job.reload).to have_attributes(same_printer: true, bound_printer: nil)
    end
  end

  describe 'refusals' do
    it 'is refused below the copies done and printing' do
      2.times { copy('completed') }
      copy('active')

      expect_refused(described_class.new(job:, copies: 2), "Can't go below 3: 2 done and 1 printing")
      expect(job.reload.copies).to eq 5
    end

    it 'goes down to the copies done and printing: the change applies to the copies still waiting' do
      2.times { copy('completed') }
      copy('active')

      expect(update(copies: 3).errors).to be_empty
      expect(job.reload).to have_attributes(copies: 3, waiting_count: 0)
    end

    it 'is refused for an entry no longer in the queue' do
      job.update!(copies: 1)
      copy('completed')

      expect_refused(described_class.new(job:, copies: 2), "#{job.item.filename} is no longer in the queue")
    end

    it 'is refused for a printer that can never print it, with why' do
      mini = create(:printer, name: 'Mini Delta', bed_shape: 'circular', build_diameter: 110)

      expect_refused(described_class.new(job:, copies: 5, all_capable: false, printer_ids: [mini.id]),
                     "Mini Delta can't print it: Bed too small: needs 123.09 × 130 mm, has a 110 mm round bed")
      expect(job.reload.all_capable).to be true
    end

    it 'checks the material asked for against the printers chosen' do
      mk4.update!(materials: ['PLA'])

      expect_refused(described_class.new(job:, copies: 5, material: 'PETG', all_capable: false,
                                         printer_ids: [mk4.id]),
                     "Prusa MK4 can't print it: Doesn't print PETG (prints PLA)")
    end

    it 'is refused for an empty printer list' do
      expect_refused(described_class.new(job:, copies: 5, all_capable: false, printer_ids: []),
                     'Choose at least one printer')
    end

    it 'is refused for a material that is not in the list' do
      expect_refused(described_class.new(job:, copies: 5, material: 'PCTG'), 'Material is not included in the list')
    end

    it 'is refused for less than one copy' do
      expect_refused(described_class.new(job:, copies: 0), 'Copies must be greater than or equal to 1')
    end
  end
end
