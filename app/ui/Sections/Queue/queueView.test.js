import { describe, expect, it } from 'vitest'

import {
  availableSummary, batchSummary, batchView, copiesFloor, copiesUnderWay, copyText, filamentLabel, isQueueEmpty,
  loadedText, needsView, nextCopyNumber, offlineText, onBedText, printLabel, printersView,
  printingSummary, swatchColour, takesNextView, waitingCopiesView, waitingSummary
} from './queueView'

const needs = (overrides) => ({ pending: false, known: true, colour: null, filaments: [], footprint: null, ...overrides })

describe('needsView', () => {
  it('lists the filament of a single tool, and the footprint', () => {
    expect(needsView(needs({
      filaments: [{ tool: 0, material: 'PLA', colour: 'Black' }], footprint: { width: 120, depth: 80.26 }
    }))).toEqual({ filaments: [{ key: 0, colour: 'Black', text: 'PLA · Black' }], footprint: '120 × 80.3 mm' })
  })

  it('names each tool when there are more than one, Any colour and Unknown material when not set', () => {
    expect(needsView(needs({
      filaments: [{ tool: 0, material: 'PETG', colour: null }, { tool: 1, material: null, colour: 'White' }]
    })).filaments.map((filament) => filament.text)).toEqual(['T0 PETG · Any colour', 'T1 Unknown material · White'])
  })

  it('says when the G-code is not read yet, or could not be', () => {
    expect(needsView(needs({ pending: true })).pending).toBe(true)
    expect(needsView(needs({ known: false })).unknown).toBe(true)
  })
})

describe('batchView', () => {
  it('shows the batch size and the copies left to start', () => {
    expect(batchView({ copies: 10, copiesLeftToStart: 4 })).toEqual({ size: '× 10', left: '4 left to start' })
  })

  it('shows nothing for a single copy', () => {
    expect(batchView({ copies: 1, copiesLeftToStart: 1 })).toBeNull()
  })
})

describe('copyText', () => {
  it('says which copy of a batch a print is', () => {
    expect(copyText({ copyNumber: 2, printJob: { copies: 3 } })).toBe('Copy 2 of 3')
    expect(copyText({ copyNumber: 1, printJob: { copies: 1 } })).toBeNull()
  })
})

describe('loadedText', () => {
  it('lists the filaments loaded', () => {
    expect(loadedText([{ material: 'PLA', colour: 'Galaxy Black' }])).toBe('PLA Galaxy Black loaded')
    expect(loadedText([])).toBe('No filament set')
    expect(loadedText()).toBe('No filament set')
  })
})

describe('isQueueEmpty', () => {
  const empty = { waiting: [], printing: [], printersToClear: [], availablePrinters: [{}], finished: [{}] }

  it('is empty with nothing waiting, printing or to clear, whatever is available or finished', () => {
    expect(isQueueEmpty(empty)).toBe(true)
    expect(isQueueEmpty({ ...empty, waiting: [{}] })).toBe(false)
    expect(isQueueEmpty({ ...empty, printing: [{}] })).toBe(false)
    expect(isQueueEmpty({ ...empty, printersToClear: [{}] })).toBe(false)
  })
})


describe('filamentLabel', () => {
  it('says a filament the frames’ way', () => {
    expect(filamentLabel({ material: 'PLA', colour: 'Black' })).toBe('PLA · Black')
    expect(filamentLabel({ material: 'PETG', colour: null })).toBe('PETG · Any colour')
    expect(filamentLabel({ material: 'PETG', colour: null }, { anyColour: false })).toBe('PETG')
  })
})

describe('swatchColour', () => {
  it('draws a colour CSS knows by its name, nothing for Any colour', () => {
    expect(swatchColour('Light Blue')).toBe('lightblue')
    expect(swatchColour(null)).toBeNull()
  })
})

describe('summaries', () => {
  const status = (stateFamily) => ({ printer: { status: { stateFamily } } })

  it('says how many printers are free, and whether they take a job', () => {
    expect(availableSummary(1, false)).toBe('1 printer free to take a job')
    expect(availableSummary(2, true)).toBe('2 printers free, not taking jobs while dispatch is paused')
    expect(availableSummary(0, false)).toBe('No printer free right now')
  })

  it('counts the prints printing and paused', () => {
    expect(printingSummary([status('PRINTING'), status('PAUSED')])).toBe('1 printing · 1 paused')
    expect(printingSummary([status('PRINTING'), status('PRINTING')])).toBe('2 prints under way')
    expect(printingSummary([status('PAUSED')])).toBe('1 paused')
    expect(printingSummary([])).toBeNull()
  })

  it('counts the waiting jobs and the prints they have left to start', () => {
    expect(waitingSummary([{ copiesLeftToStart: 7 }, { copiesLeftToStart: 1 }])).toBe('2 jobs · 8 prints')
    expect(waitingSummary([{ copiesLeftToStart: 1 }])).toBe('1 job · 1 print')
  })
})

const BRACKET = { id: '5', copies: 10, copiesLeftToStart: 7, file: { filename: 'bracket_v3.gcode' } }
const onBed = (filename, copies, copyNumber, result = 'COMPLETED') => ({ copyNumber, result, printJob: { copies, file: { filename } } })

describe('takesNextView', () => {
  const printer = (more) => ({ takesJobs: true, takesNext: BRACKET, ...more })

  it('says what a printer to clear takes once its bed is cleared, and what is on its bed', () => {
    expect(takesNextView(printer(), { paused: false, toClear: true, onBed: onBed('bracket_v3.gcode', 10, 2) })).toEqual({
      text: 'bracket_v3.gcode, once its bed is cleared', detail: 'Copy 2 of 10 is finished and still on the bed'
    })
  })

  it('says nothing is taken while dispatch is paused', () => {
    expect(takesNextView(printer(), { paused: true, toClear: true }).text).toBe('Nothing while dispatch is paused')
    expect(takesNextView(printer(), { paused: true })).toEqual({
      text: 'Nothing while dispatch is paused', detail: 'It takes bracket_v3.gcode when dispatch resumes'
    })
  })

  it('says a free printer starts the copy it takes next', () => {
    expect(takesNextView(printer(), { paused: false }).text).toBe('Starting bracket_v3.gcode · copy 4 of 10')
    expect(takesNextView(printer({ takesNext: null }), { paused: false }).text).toBe('Nothing waiting it can print')
  })

  it('says a printer that takes no job takes nothing', () => {
    expect(takesNextView(printer({ takesJobs: false }), { paused: false }).text).toBe('Not taking jobs from the queue')
  })
})

describe('onBedText', () => {
  it('names the print on the bed, by its file when it isn’t the one taken next', () => {
    expect(onBedText(onBed('hinge.gcode', 1, 1), BRACKET)).toBe('hinge.gcode is finished and still on the bed')
    expect(onBedText(onBed('hinge.gcode', 4, 2, 'FAILED'), BRACKET)).toBe('hinge.gcode · copy 2 of 4 failed and is still on the bed')
    expect(onBedText(null, BRACKET)).toBe('Its last print is still on the bed')
  })
})

describe('offlineText', () => {
  it('says why an offline printer takes no job', () => {
    expect(offlineText({ name: 'Prusa Mini', status: null })).toBe('Prusa Mini is offline and takes no jobs.')
    expect(offlineText({ name: 'Prusa Mini', status: { stateFamily: 'ERROR' } })).toBe('Prusa Mini is in error and takes no jobs.')
  })
})

describe('nextCopyNumber and printLabel', () => {
  it('numbers the copy a printer takes next, and names a finished copy', () => {
    expect(nextCopyNumber(BRACKET)).toBe(4)
    expect(printLabel(onBed('bracket_v3.gcode', 10, 2))).toBe('bracket_v3.gcode · copy 2 of 10')
    expect(printLabel(onBed('hinge_pin.gcode', 1, 1))).toBe('hinge_pin.gcode')
  })
})

const MK4 = { id: '1', name: 'Prusa MK4' }
const job = (more) => ({
  copies: 1, copiesLeftToStart: 1, samePrinter: false, allCapable: true, boundPrinter: null, prints: [],
  eligiblePrinters: [MK4, { id: '2', name: 'Voron 2.4' }], ...more
})

describe('printersView', () => {
  it('says how many printers can take a job, and which', () => {
    expect(printersView(job())).toEqual({ title: '2 printers', detail: 'All that can print it' })
    expect(printersView(job({ allCapable: false, eligiblePrinters: [MK4] }))).toEqual({ title: '1 printer', detail: 'Prusa MK4' })
    expect(printersView(job({ eligiblePrinters: [] }))).toEqual({ title: 'No printer', detail: 'None can print it' })
  })

  it('says how a same-printer batch goes', () => {
    expect(printersView(job({ samePrinter: true, copies: 2, copiesLeftToStart: 2 })))
      .toEqual({ title: '2 printers', detail: 'First ready one takes both copies' })
    expect(printersView(job({ samePrinter: true, boundPrinter: MK4 }))).toEqual({ title: 'Prusa MK4', detail: 'Has the batch' })
  })
})

describe('batchSummary and waitingCopiesView', () => {
  const prints = [
    { result: 'COMPLETED', status: 'COMPLETED' }, { result: 'COMPLETED', status: 'COMPLETED' },
    { result: null, status: 'ACTIVE' }
  ]
  const batch = job({ copies: 10, copiesLeftToStart: 7, prints })

  it('counts a batch’s copies', () => {
    expect(batchSummary(batch)).toBe('2 done · 1 printing · 7 waiting')
    expect(batchSummary({ ...batch, samePrinter: true, boundPrinter: MK4 }))
      .toBe('All on Prusa MK4 · 2 done · 1 printing · 7 waiting')
  })

  it('groups the copies left to start', () => {
    expect(waitingCopiesView(batch)).toEqual({
      label: 'Copies 4 to 10', printer: 'Not assigned yet', detail: 'Each goes to the next ready printer'
    })
    expect(waitingCopiesView({ ...batch, samePrinter: true, boundPrinter: MK4 })).toEqual({
      label: 'Copies 4 to 10', printer: 'Prusa MK4', detail: 'One after another, after copy 3'
    })
    expect(waitingCopiesView({ ...batch, copiesLeftToStart: 1 }).label).toBe('Copy 10 of 10')
  })
})

describe('copiesFloor', () => {
  const job = (...statuses) => ({ prints: statuses.map((status, index) => ({ id: String(index), status })) })

  it('counts the copies done and handed to a printer, failed ones aside', () => {
    expect(copiesFloor(job('COMPLETED', 'ACTIVE', 'ENQUEUED', 'ERROR', 'CANCELLED'))).toBe(3)
    expect(copiesUnderWay(job('COMPLETED', 'ACTIVE', 'ENQUEUED', 'ERROR'))).toBe(2)
  })

  it('is at least 1', () => {
    expect(copiesFloor(job())).toBe(1)
    expect(copiesFloor(job('ERROR'))).toBe(1)
  })
})
