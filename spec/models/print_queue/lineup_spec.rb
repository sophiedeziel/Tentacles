# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PrintQueue::Lineup do
  let(:mk4) { printer(name: 'Prusa MK4') }
  let(:operational) { status(Printer::StateFamily::Operational) }

  def status(family) = Printer::Status.new(printer_id: 1, state_family: family, state_text: family.serialize.capitalize)

  # A printer with this filament loaded
  def printer(material: 'PLA', colour: 'Black', **attributes)
    create(:printer, **attributes).tap do |printer|
      create(:printer_loaded_filament, printer:, material:, colour:)
    end
  end

  # An entry whose summary is read: one tool per material
  def entry(materials: ['PLA'], **attributes)
    create(:print_job, **attributes).tap do |job|
      create(:gcode_summary, :ready, :with_tools, item: job.item, materials:)
    end
  end

  def lineup(printer = mk4, status: operational)
    printer = Printer.includes(:loaded_filaments).find(printer.id)
    described_class.new(printer:, status:, entries: PrintQueue::NextJob.candidates,
                        printers: Printer.order(:id).to_a)
  end

  def skipped(lineup = self.lineup) = lineup.skipped.map { |skip| [skip.entry, skip.reasons] }

  it 'lists the entries it qualifies for in queue order, and skips none' do
    second = entry(position: 2)
    first = entry(position: 1, colour: 'Black')

    expect(lineup.up_next).to eq [first, second]
    expect(lineup.skipped).to be_empty
  end

  it 'keeps a held entry up next: it is on hold until released' do
    held = entry(held: true)

    expect(lineup.up_next).to eq [held]
  end

  it 'leaves out the entries with no copy waiting' do
    printing = entry(copies: 1)
    create(:printer_job, :copy, print_job: printing, printer: mk4, status: 'active')
    done = entry(copies: 1)
    create(:printer_job, :copy, print_job: done, printer: mk4, status: 'completed', finished_at: 1.hour.ago)

    expect(lineup.up_next).to be_empty
    expect(lineup.skipped).to be_empty
  end

  it 'counts an entry it can print once it reconnects as up next' do
    queued = entry

    expect(lineup(status: nil).up_next).to eq [queued]
  end

  it 'counts the printer own state as no reason: not taking jobs, busy' do
    mk4.update!(takes_jobs: false)
    queued = entry

    expect(lineup(status: status(Printer::StateFamily::Printing)).up_next).to eq [queued]
  end

  describe 'skipped' do
    it 'says what filament to change, in the printer page wording' do
      petg = entry(position: 1, materials: ['PETG'])
      white = entry(position: 2, colour: 'White')

      expect(skipped).to eq [
        [petg, ['Needs PETG, PLA is loaded here']],
        [white, ['Needs PLA White, PLA Black is loaded here']]
      ]
      expect(lineup.up_next).to be_empty
    end

    it 'says what filament to change while the printer is offline too' do
      petg = entry(materials: ['PETG'])

      expect(skipped(lineup(status: nil))).to eq [[petg, ['Needs PETG, PLA is loaded here']]]
    end

    it 'names the printers an entry is limited to' do
      voron = printer(name: 'Voron 2.4')
      xl = printer(name: 'Prusa XL')
      limited = entry(all_capable: false)
      create(:print_job_printer, job: limited, printer: voron)
      create(:print_job_printer, job: limited, printer: xl)

      expect(skipped).to eq [[limited, ['Limited to Voron 2.4, Prusa XL']]]
      expect(lineup(voron).up_next).to eq [limited]
    end

    it 'names the printer a same-printer batch is bound to' do
      xl = printer(name: 'Prusa XL')
      batch = entry(copies: 3, same_printer: true, bound_printer: xl)

      expect(skipped).to eq [[batch, ['Same-printer batch on Prusa XL']]]
      expect(lineup(xl).up_next).to eq [batch]
    end

    it 'gives the hard limitations, not the filament' do
      too_big = entry(materials: ['PETG'])
      mk4.update!(build_volume_x: 100, build_volume_y: 100)

      expect(skipped).to eq [[too_big, ['Bed too small: needs 123.09 × 130 mm, has 100 × 100 mm']]]
    end

    it 'gives every reason that applies' do
      xl = printer(name: 'Prusa XL')
      limited = entry(all_capable: false, materials: ['PETG'])
      create(:print_job_printer, job: limited, printer: xl)

      expect(skipped).to eq [[limited, ['Limited to Prusa XL', 'Needs PETG, PLA is loaded here']]]
    end

    it 'skips an entry whose G-code is still being read' do
      pending = create(:print_job)
      create(:gcode_summary, item: pending.item)

      expect(skipped).to eq [[pending, ['Its G-code is still being read']]]
    end
  end

  it 'puts every entry with copies waiting in one of the two lists, in queue order' do
    entries = [entry(position: 1), entry(position: 2, materials: ['PETG']), entry(position: 3, held: true)]
    result = lineup

    expect(result.up_next + result.skipped.map(&:entry)).to contain_exactly(*entries)
    expect(result.skipped.map(&:entry)).to eq [entries[1]]
  end

  it 'reads nothing more once its inputs are loaded' do
    entry(position: 1)
    entry(position: 2, materials: ['PETG'])
    result = lineup

    queries = []
    counter = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { result.up_next && result.skipped }

    expect(queries).to be_empty
  end
end
