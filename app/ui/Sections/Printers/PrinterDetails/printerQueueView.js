// What the printer page's part of the global queue says, apart from its components (the PrinterQueue frame)

import { needsView, printLabel } from '../../Queue/queueView'

const UNTIL_CLEARED = 'This printer takes no new job until you confirm the bed is clear.'

// The bed banner: the print still on the bed ("bracket_v3.gcode · copy 2 of 10 is done."), how it ended, and that
// the printer waits for Bed Cleared. `print`: Printer.printOnBed (null when not known).
export function bedBannerView (print) {
  if (!print) return { title: 'Remove the last print', text: UNTIL_CLEARED }
  const label = printLabel(print)
  if (print.result === 'FAILED') return { title: 'Print failed: remove the part', text: `${label} failed. ${UNTIL_CLEARED}` }
  if (print.result === 'CANCELLED') {
    return { title: 'Print cancelled: remove the part', text: `${label} was cancelled. ${UNTIL_CLEARED}` }
  }
  return { title: 'Print finished: remove the part', text: `${label} is done. ${UNTIL_CLEARED}` }
}

// An Up Next row's line under its file: "Batch of 10 · 7 left to start", or "1 print"
export function jobSizeText (job) {
  if (job.copies <= 1) return '1 print'
  return `Batch of ${job.copies} · ${job.copiesLeftToStart} left to start`
}

// An Up Next row's needs, one line per tool ("PLA · Black", "T1 PETG · Any colour")
export function needsLines (needs) {
  const view = needsView(needs)
  if (view.pending) return ['Reading the G-code']
  if (view.unknown || view.filaments.length === 0) return ['Not known']
  return view.filaments.map((filament) => filament.text)
}

// Skipped by This Printer's line: "3 jobs it can't take, and why"
export function skippedSummary (count) {
  return `${count === 1 ? '1 job' : `${count} jobs`} it can't take, and why`
}

// The takes-jobs switch's label
export function takesJobsText (takesJobs) {
  return takesJobs ? 'Taking jobs from the queue' : 'Not taking jobs'
}
