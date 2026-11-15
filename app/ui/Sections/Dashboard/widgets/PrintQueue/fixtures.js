// A fleet with queued and finished jobs, as the dashboard queries return them: for tests and the Add Widget
// gallery. Times are relative to FIXTURE_NOW.
import { FIXTURE_NOW, PRINTERS } from '../Printer/fixtures'

export { FIXTURE_NOW }

const MINUTE = 60 * 1000

const job = (id, filename, printer, extra = {}) => ({
  id,
  status: 'enqueued',
  updatedAt: FIXTURE_NOW.toISOString(),
  executable: { id: `file-${id}`, filename },
  printer: { id: printer.id, name: printer.name },
  ...extra
})

const finished = (id, filename, printer, status, minutesAgo) => job(id, filename, printer, {
  status, updatedAt: new Date(FIXTURE_NOW.getTime() - minutesAgo * MINUTE).toISOString()
})

// Printing, paused, stopped responding, and ready with two jobs waiting
export const FLEET = [PRINTERS.PRINTING, PRINTERS.PAUSED, PRINTERS.ERROR, PRINTERS.OPERATIONAL]

// FLEET's queue, in enqueue order (Prusa MK4 has 3 jobs, Prusa Mini+ 2, Voron 2.4 1)
export const QUEUE = {
  totalCount: 6,
  jobs: [
    job('11', 'spool_holder.gcode', PRINTERS.OPERATIONAL),
    job('12', 'cable_clip_x20.gcode', PRINTERS.PRINTING),
    job('13', 'lid_hinge_v4.gcode', PRINTERS.PRINTING),
    job('14', 'calibration_cube.gcode', PRINTERS.PAUSED),
    job('15', 'phone_stand.gcode', PRINTERS.OPERATIONAL),
    job('16', 'drawer_knob_set.gcode', PRINTERS.PRINTING)
  ]
}

// FLEET's finished jobs, the last finished first
export const HISTORY = [
  finished('21', 'gear_v2.gcode', PRINTERS.ERROR, 'error', 40),
  finished('22', 'cable_comb.gcode', PRINTERS.OPERATIONAL, 'completed', 60),
  finished('23', 'bracket_v2.gcode', PRINTERS.PRINTING, 'completed', 120),
  finished('24', 'enclosure_door.gcode', PRINTERS.PAUSED, 'completed', 300),
  finished('25', 'benchy.gcode', PRINTERS.PRINTING, 'completed', 1500)
]

// One printer's part of QUEUE and HISTORY
export function queueOf (printer) {
  const jobs = QUEUE.jobs.filter((queued) => queued.printer.id === printer.id)
  return { totalCount: jobs.length, jobs }
}

export function historyOf (printer) {
  return HISTORY.filter((done) => done.printer.id === printer.id)
}

// A Print Queue widget's options with everything on
export const ALL_OPTIONS = { nowPrinting: true, startNext: true, rowPerPrinter: true, history: true }
