import { describe, expect, it } from 'vitest'

import { hexColour, nearestColourName } from './colours'
import {
  ANY_COLOUR, clearAll, colourHint, fillEmpty, fitView, gcodeFilament, jobVariables, materialHint, selectAll,
  selectedPrinterIds, summaryView, tick
} from './formRules'

const summary = (tools, overrides = {}) => ({ status: 'READY', toolCount: tools.length, tools, ...overrides })
const tool = (material, colourHex, materialRaw = material) => ({ tool: 0, material, materialRaw, colourHex })
const printer = (id, loaded = null) => ({
  id, name: `Printer ${id}`, loadedFilaments: loaded ? [{ slot: 1, ...loaded }] : []
})
const fit = (id, result, { hardLimit = false, reasons = [], loaded } = {}) => ({
  result, hardLimit, reasons, printer: printer(id, loaded)
})
const FITS = [fit('1', 'READY'), fit('2', 'READY'), fit('3', 'CANNOT', { hardLimit: true })]

describe('nearestColourName', () => {
  it('reads a hex as the nearest named colour', () => {
    expect(nearestColourName('#1A1A1A')).toBe('Black')
    expect(nearestColourName('#FFFFFF')).toBe('White')
    expect(nearestColourName('FF8000')).toBe('Orange')
    expect(nearestColourName('#8a8a8a')).toBe('Grey')
    expect(nearestColourName('#C8C8C8')).toBe('Silver')
    expect(nearestColourName('#2050E0')).toBe('Blue')
    expect(nearestColourName('#E02020')).toBe('Red')
    expect(nearestColourName('#F00')).toBe('Red')
  })

  it('is null for no hex, or one it cannot read', () => {
    expect(nearestColourName(null)).toBeNull()
    expect(nearestColourName('')).toBeNull()
    expect(nearestColourName('black')).toBeNull()
  })

  it('normalises the hex for the swatch, the alpha dropped', () => {
    expect(hexColour('ff8800')).toBe('#FF8800')
    expect(hexColour('#f80')).toBe('#FF8800')
    expect(hexColour('#FF8800AA')).toBe('#FF8800')
    expect(hexColour('nope')).toBeNull()
  })
})

describe('gcodeFilament', () => {
  it('reads the first tool of a summary read', () => {
    expect(gcodeFilament(summary([tool('PLA', '#1A1A1A')]))).toEqual({
      status: 'READY', material: 'PLA', raw: null, colour: 'Black', hex: '#1A1A1A', tools: 1
    })
  })

  it('keeps a raw material outside the closed list as a hint', () => {
    expect(gcodeFilament(summary([tool(null, null, 'PCTG')]))).toMatchObject({ material: null, raw: 'PCTG', colour: null })
  })

  it('says nothing while the summary is pending, or when it failed', () => {
    expect(gcodeFilament({ status: 'PENDING', tools: [] })).toMatchObject({ status: 'PENDING', material: null, colour: null })
    expect(gcodeFilament({ status: 'FAILED', tools: [] })).toMatchObject({ status: 'FAILED', material: null, colour: null })
  })
})

describe('fillEmpty', () => {
  const gcode = { material: 'PLA', colour: 'Black' }

  it('fills the empty fields with what the G-code says', () => {
    expect(fillEmpty({ material: null, colour: null }, gcode)).toEqual({ material: 'PLA', colour: 'Black' })
  })

  it('never replaces a field that has a value', () => {
    expect(fillEmpty({ material: 'PETG', colour: ANY_COLOUR }, gcode)).toEqual({ material: 'PETG', colour: ANY_COLOUR })
    expect(fillEmpty({ material: null, colour: 'Red' }, gcode)).toEqual({ material: 'PLA', colour: 'Red' })
  })

  it('leaves the fields empty when the G-code says nothing (pending or failed)', () => {
    expect(fillEmpty({ material: null, colour: null }, { material: null, colour: null }))
      .toEqual({ material: null, colour: null })
  })
})

describe('the hints', () => {
  const gcode = { status: 'READY', material: 'PLA', raw: null, colour: 'Black', tools: 1 }

  it('says where a material comes from', () => {
    expect(materialHint('PLA', gcode)).toBe('From the G-code')
    expect(materialHint('PETG', gcode)).toBe('The G-code says PLA')
    expect(materialHint(null, { ...gcode, material: null, raw: 'PCTG' }))
      .toBe('The G-code says PCTG, which is not a material the queue can match')
    expect(materialHint(null, { ...gcode, status: 'PENDING' })).toBe('Reading the G-code…')
    expect(materialHint(null, { ...gcode, status: 'FAILED' })).toMatch("The G-code couldn't be read")
  })

  it('says where a colour comes from', () => {
    expect(colourHint('Black', gcode)).toBe('From the G-code. Any Colour lets more printers take it')
    expect(colourHint(ANY_COLOUR, { ...gcode, colour: 'Grey' })).toBe('Any colour is accepted. The G-code says Grey')
    expect(colourHint('Red', gcode)).toBe('Asked for. The G-code says Black')
  })
})

describe('the printer selection', () => {
  const untouched = { touched: false, ticked: [] }

  it('selects every printer that can print it until the person changes it', () => {
    expect(selectedPrinterIds(FITS, untouched)).toEqual(['1', '2'])
  })

  it("keeps the person's ticks through a recompute, and leaves out a printer that can no longer print it", () => {
    const selection = tick(FITS, untouched, '2', false)
    expect(selection).toEqual({ touched: true, ticked: ['1'] })

    const recomputed = [fit('1', 'CANNOT', { hardLimit: true }), fit('2', 'READY'), fit('3', 'READY')]
    expect(selectedPrinterIds(recomputed, selection)).toEqual([])
    expect(selectedPrinterIds(FITS, selection)).toEqual(['1'])
  })

  it('selects all, or none', () => {
    expect(selectedPrinterIds(FITS, selectAll(FITS))).toEqual(['1', '2'])
    expect(selectedPrinterIds(FITS, clearAll())).toEqual([])
  })
})

describe('fitView', () => {
  it('words every fit like the frame', () => {
    expect(fitView(fit('1', 'READY', { loaded: { material: 'PLA', colour: 'Black' } })))
      .toEqual({ mark: 'ready', text: 'Can print it. PLA Black loaded' })
    expect(fitView(fit('1', 'AFTER_FILAMENT_CHANGE', { loaded: { material: 'PETG', colour: 'Grey' } })))
      .toEqual({ mark: 'waiting', text: 'Can print it after a filament change. PETG Grey loaded' })
    expect(fitView(fit('1', 'AFTER_FILAMENT_CHANGE')).text).toBe('Can print it after a filament change. No filament loaded')
    expect(fitView(fit('1', 'AFTER_RECONNECT', { reasons: [{ code: 'OFFLINE', message: 'Offline' }] })).text)
      .toBe('Can print it once it reconnects')
    expect(fitView(fit('1', 'AFTER_RECONNECT', {
      reasons: [{ code: 'OFFLINE', message: 'Offline' }, { code: 'NO_FILAMENT', message: 'Needs PLA Black. No filament is loaded here' }]
    })).text).toBe('Can print it once it reconnects and its filament is set')
    expect(fitView(fit('1', 'CANNOT', {
      hardLimit: true, reasons: [{ code: 'BED_TOO_SMALL', message: 'Bed too small: needs 120 × 80 mm, has a 110 mm round bed' }]
    }))).toEqual({ mark: 'cannot', text: "Can't print it: bed too small: needs 120 × 80 mm, has a 110 mm round bed" })
  })
})

describe('summaryView', () => {
  const estimate = {
    printing: 2,
    waitingJobs: 5,
    jobsAhead: 5,
    printsAhead: 15,
    copiesToPrint: 10,
    filaments: [{ tool: 0, material: 'PLA', colour: 'Black', grams: 180, metres: 60 }],
    filamentGrams: 180,
    filamentMetres: 60,
    printSeconds: 42000
  }

  it('reads the queue, the filament and the print time', () => {
    const view = summaryView(estimate, { samePrinter: false, readyPrinters: 2 })

    expect(view.queueNow).toEqual({ title: '2 printing · 5 jobs waiting', detail: 'Ahead of this job: 5 jobs · 15 prints' })
    expect(view.filament.title).toBe('180 g · 60 m')
    expect(view.filament.lines).toEqual([{ key: 0, material: 'PLA', colour: 'Black', amount: '180 g · 60 m' }])
    expect(view.printTime).toEqual({ title: '11 h 40 min', detail: 'All copies, about 5 h 50 min on 2 printers at once' })
  })

  it('prints a same-printer batch one copy after another', () => {
    expect(summaryView(estimate, { samePrinter: true, readyPrinters: 2 }).printTime.detail).toBe('All copies, one after another')
    expect(summaryView(estimate, { samePrinter: false, readyPrinters: 1 }).printTime.detail).toBe('All copies, one after another')
  })

  it('says Not known for what is not', () => {
    const view = summaryView({ ...estimate, jobsAhead: 0, filamentGrams: null, filamentMetres: null, printSeconds: null, filaments: [] },
      { samePrinter: false, readyPrinters: 2 })

    expect(view.queueNow.detail).toBe('Nothing ahead of this job')
    expect(view.filament.title).toBe('Not known')
    expect(view.printTime).toEqual({ title: 'Not known', detail: null })
  })
})

describe('jobVariables', () => {
  const form = { copies: 3, material: 'PLA', colour: ANY_COLOUR, samePrinter: false, position: 'TOP', held: true }

  it('saves the automatic selection as every printer that can print it (no printerIds), Any Colour as null', () => {
    expect(jobVariables(form, { fits: FITS, selection: { touched: false, ticked: [] } })).toEqual({
      copies: 3, material: 'PLA', colour: null, samePrinter: false, printerIds: null, position: 'TOP', held: true
    })
  })

  it('saves the explicit list once the person changed the selection', () => {
    expect(jobVariables(form, { fits: FITS, selection: { touched: true, ticked: ['2', '3'] } }).printerIds).toEqual(['2'])
  })
})
