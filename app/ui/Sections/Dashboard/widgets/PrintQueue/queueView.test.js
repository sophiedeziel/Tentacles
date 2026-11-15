import { describe, expect, it } from 'vitest'
import queueView, { bucketOf, fitNextRows, foldRows, rowsToLoad, sortPrinters } from './queueView'
import { ALL_OPTIONS, FIXTURE_NOW, FLEET, HISTORY, QUEUE, historyOf, queueOf } from './fixtures'
import { PRINTERS } from '../Printer/fixtures'

const view = (size, { printer = null, options = {}, printers = FLEET, queue, history } = {}) => queueView({
  printers,
  printerId: printer?.id ?? null,
  size,
  options: { ...ALL_OPTIONS, ...options },
  queue: queue !== undefined ? queue : (printer ? queueOf(printer) : QUEUE),
  history: history !== undefined ? history : (printer ? historyOf(printer) : HISTORY),
  now: FIXTURE_NOW
})

// A printer in `family`, named `name`, with `queued` jobs
const farmPrinter = (id, name, family, queued = 0) => ({
  ...PRINTERS[family],
  id,
  name,
  queuedCount: queued,
  canStartNext: family === 'OPERATIONAL' && queued > 0,
  nextJob: queued > 0 ? { id: `next-${id}`, executable: { id: `f-${id}`, filename: `${name}.gcode` } } : null
})

describe('queueView', () => {
  describe('sorting the per-printer table', () => {
    it('puts ready printers with work waiting first, then printing, paused, error, and idle and offline last', () => {
      const printers = [
        farmPrinter('1', 'Kobra 2', 'OFFLINE'),
        farmPrinter('2', 'Sovol SV06', 'OPERATIONAL'),
        farmPrinter('3', 'Ender 3 V2', 'ERROR'),
        farmPrinter('4', 'Voron 2.4', 'PAUSED', 1),
        farmPrinter('5', 'Prusa MK4', 'PRINTING', 3),
        farmPrinter('6', 'Prusa XL', 'OPERATIONAL', 2),
        farmPrinter('7', 'Bambu X1C', 'PRINTING', 1),
        farmPrinter('8', 'Voron Trident', 'CONNECTING'),
        farmPrinter('9', 'Ender 5 Plus', 'CANCELLING')
      ]
      expect(sortPrinters(printers).map((printer) => printer.name)).toEqual([
        'Prusa XL', 'Bambu X1C', 'Prusa MK4', 'Ender 5 Plus', 'Voron 2.4', 'Ender 3 V2', 'Voron Trident',
        'Sovol SV06', 'Kobra 2'
      ])
    })

    it('tells ready printers with work waiting from idle ones', () => {
      expect(bucketOf(farmPrinter('1', 'A', 'OPERATIONAL', 1))).toBe('ready')
      expect(bucketOf(farmPrinter('1', 'A', 'OPERATIONAL', 0))).toBe('idle')
    })
  })

  describe('folding the per-printer table', () => {
    const rows = (buckets) => buckets.map((bucket, index) => ({ id: String(index), bucket }))

    it('shows every row when they fit', () => {
      expect(foldRows(rows(['ready', 'printing', 'idle']), 3)).toEqual({ shown: rows(['ready', 'printing', 'idle']), moreText: null })
    })

    it('folds the rest into "+ N more printers", counting them by state, with no "need attention" bucket', () => {
      const folded = foldRows(rows(['ready', 'printing', 'printing', 'paused', 'idle', 'error', 'idle', 'offline']), 4)
      expect(folded.shown.map((row) => row.bucket)).toEqual(['ready', 'printing', 'printing'])
      expect(folded.moreText).toBe('+ 5 more printers: 1 paused · 1 in error · 2 idle · 1 offline')
    })

    it('never folds a single printer: its row takes the summary line\'s place', () => {
      expect(foldRows(rows(['printing', 'printing', 'idle']), 3).moreText).toBeNull()
      expect(foldRows(rows(['printing', 'printing', 'idle']), 2).moreText).toBe('+ 2 more printers: 1 printing · 1 idle')
    })

    it('shows 5 printers and the summary at XL past 6, 9 at XXL past 10', () => {
      const farm = Array.from({ length: 12 }, (_, index) => farmPrinter(String(index), `Printer ${index}`, 'OPERATIONAL'))
      farm[0] = farmPrinter('0', 'Printer 0', 'PRINTING', 1)
      const xl = view('XL', { printers: farm, queue: null })
      expect(xl.shown).toHaveLength(5)
      expect(xl.moreText).toBe('+ 7 more printers: 7 idle')
      const xxl = view('XXL', { printers: farm, queue: null })
      expect(xxl.shown).toHaveLength(9)
      expect(xxl.moreText).toBe('+ 3 more printers: 3 idle')
      expect(view('XXL', { printers: farm.slice(0, 10), queue: null }).moreText).toBeNull()
    })
  })

  describe('rows to load', () => {
    it('loads only the rows each size shows', () => {
      const off = { rowPerPrinter: false, history: false }
      expect(rowsToLoad('S', ALL_OPTIONS, false)).toEqual({ queue: 0, history: 0 })
      expect(rowsToLoad('M', ALL_OPTIONS, false)).toEqual({ queue: 3, history: 0 })
      expect(rowsToLoad('L', ALL_OPTIONS, true)).toEqual({ queue: 8, history: 0 })
      expect(rowsToLoad('XL', ALL_OPTIONS, false)).toEqual({ queue: 0, history: 0 }) // the table reads the printers
      expect(rowsToLoad('XL', ALL_OPTIONS, true)).toEqual({ queue: 8, history: 7 })
      expect(rowsToLoad('XL', { ...ALL_OPTIONS, ...off }, false)).toEqual({ queue: 8, history: 0 })
      expect(rowsToLoad('XXL', ALL_OPTIONS, false)).toEqual({ queue: 5, history: 5 })
      expect(rowsToLoad('XXL', ALL_OPTIONS, true)).toEqual({ queue: 15, history: 16 })
    })
  })

  it('fits fewer up next rows under printing jobs and above the ready bar, keeping room for "+ N more"', () => {
    expect(fitNextRows(304, { nowCount: 0, single: false, ready: false, total: 3, max: 8 })).toBe(8)
    expect(fitNextRows(304, { nowCount: 0, single: false, ready: true, total: 9, max: 8 })).toBe(6)
    expect(fitNextRows(304, { nowCount: 2, single: false, ready: true, total: 6, max: 8 })).toBe(2)
    expect(fitNextRows(304, { nowCount: 1, single: true, ready: false, total: 2, max: 8 })).toBe(5)
  })

  describe('all printers', () => {
    it('counts the queued jobs at Small', () => {
      expect(view('S', { queue: null })).toMatchObject({ title: 'Print Queue', count: 6, countLabel: 'jobs queued' })
    })

    it('shows what prints now, then the next jobs with their printer, at Medium', () => {
      expect(view('M').rows.map((row) => [row.file, row.isNow ? row.side : row.printer])).toEqual([
        ['bracket_v3.gcode', 'Prusa MK4'],
        ['spool_holder.gcode', 'Prusa Mini+'],
        ['cable_clip_x20.gcode', 'Prusa MK4']
      ])
      expect(view('M', { options: { nowPrinting: false } }).rows.map((row) => row.pos)).toEqual([1, 2, 3])
    })

    it('takes progress and time left from the live status, not the job', () => {
      const [printing, paused] = view('L').now
      expect(printing).toMatchObject({ file: 'bracket_v3.gcode', progress: 64, printer: 'Prusa MK4 · 1 h 12 min left' })
      expect(paused).toMatchObject({ file: 'enclosure_panel.gcode', progress: 38, printer: 'Voron 2.4 · Paused at 38%' })
    })

    it('fits the printing jobs, the next jobs, "+ N more" and the ready bar at Large', () => {
      const large = view('L')
      expect(large.next.map((row) => row.file)).toEqual(['spool_holder.gcode', 'cable_clip_x20.gcode'])
      expect(large.moreText).toBe('+ 4 more')
      expect(large.ready.label).toBe('Prusa Mini+ is ready for spool_holder.gcode')
      expect(view('L', { options: { nowPrinting: false } }).next).toHaveLength(6)
      expect(view('L', { options: { startNext: false } }).ready).toBeNull()
    })

    it('shows one row per printer at XL, in table order, each with its next job and count', () => {
      const xl = view('XL', { queue: null })
      expect(xl.table).toBe(true)
      expect(xl.shown.map((row) => [row.printer.name, row.current?.short ?? row.nowText, row.nextFile, row.count, row.canStart]))
        .toEqual([
          ['Prusa Mini+', 'Idle', 'spool_holder.gcode +1', 2, true],
          ['Prusa MK4', '1 h 12 min', 'cable_clip_x20.gcode +2', 3, false],
          ['Voron 2.4', '38%', 'calibration_cube.gcode', 1, false],
          ['Ender 3 V2', 'Stopped responding', 'Nothing queued', 0, false]
        ])
      expect(view('XL', { queue: null, options: { startNext: false } }).shown[0].canStart).toBe(false)
    })

    it('lists the up next jobs and history under the table at XXL', () => {
      const xxl = view('XXL')
      expect(xxl.under.next.map((row) => row.file)).toHaveLength(5)
      expect(xxl.under.history[0]).toEqual({ id: '21', file: 'gear_v2.gcode', status: 'error', side: 'Ender 3 V2 · 40 min ago' })
    })

    it('lists all printers as one queue with history beside it when one row per printer is off', () => {
      const xl = view('XL', { options: { rowPerPrinter: false } })
      expect(xl.table).toBeUndefined()
      expect(xl.list).toBe(true)
      expect(xl.showHistory).toBe(true)
      expect(xl.history.map((row) => row.status)).toEqual(['error', 'completed', 'completed', 'completed', 'completed'])
    })

    it('is empty with nothing printing or queued', () => {
      const idle = [farmPrinter('1', 'Prusa MK4', 'OPERATIONAL'), farmPrinter('2', 'Prusa Mini+', 'OPERATIONAL')]
      const empty = { totalCount: 0, jobs: [] }
      expect(view('M', { printers: idle, queue: empty })).toMatchObject({ empty: true, queuedLabel: 'Nothing queued' })
      expect(view('XL', { printers: idle, queue: empty })).toMatchObject({ empty: true, list: false })
      expect(view('XL', { printers: idle, queue: null }).table).toBeUndefined()
    })
  })

  describe('one printer', () => {
    it('names the printer in the title and drops the printer column', () => {
      const medium = view('M', { printer: PRINTERS.PRINTING })
      expect(medium.title).toBe('Prusa MK4 queue')
      expect(view('S', { printer: PRINTERS.PRINTING })).toMatchObject({ smallTitle: 'Prusa MK4', count: 3 })
      expect(medium.rows.map((row) => [row.file, row.isNow ? row.side : row.printer])).toEqual([
        ['bracket_v3.gcode', '1 h 12 min left'],
        ['cable_clip_x20.gcode', ''],
        ['lid_hinge_v4.gcode', '']
      ])
    })

    it('never shows one row per printer, and offers Start Next when its printer is ready', () => {
      const ready = view('XL', { printer: PRINTERS.OPERATIONAL })
      expect(ready.table).toBeUndefined()
      expect(ready.list).toBe(true)
      expect(ready.ready.label).toBe('Prusa Mini+ is ready for spool_holder.gcode')
    })

    it('keeps its history when nothing is queued, so a failed job stays visible', () => {
      const failed = view('XL', { printer: PRINTERS.ERROR })
      expect(failed).toMatchObject({ empty: true, list: true, queuedLabel: 'Nothing queued' })
      expect(failed.history).toEqual([{ id: '21', file: 'gear_v2.gcode', status: 'error', side: '40 min ago' }])
      expect(view('XL', { printer: PRINTERS.ERROR, options: { history: false } }).list).toBe(false)
    })
  })
})
