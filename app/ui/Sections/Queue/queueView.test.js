import { describe, expect, it } from 'vitest'

import { batchView, copyText, isQueueEmpty, lastPrintByPrinter, loadedText, needsView } from './queueView'

const needs = (overrides) => ({ pending: false, known: true, colour: null, filaments: [], footprint: null, ...overrides })

describe('needsView', () => {
  it('lists the filament of a single tool, and the footprint', () => {
    expect(needsView(needs({
      filaments: [{ tool: 0, material: 'PLA', colour: 'Black' }], footprint: { width: 120, depth: 80.26 }
    }))).toEqual({ filaments: [{ key: 0, text: 'PLA Black' }], footprint: '120 × 80.3 mm' })
  })

  it('names each tool when there are more than one, Any colour and Unknown material when not set', () => {
    expect(needsView(needs({
      filaments: [{ tool: 0, material: 'PETG', colour: null }, { tool: 1, material: null, colour: 'White' }]
    })).filaments.map((filament) => filament.text)).toEqual(['T0 PETG Any colour', 'T1 Unknown material White'])
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

describe('lastPrintByPrinter', () => {
  it('keeps the first (latest) finished print of each printer', () => {
    const prints = [{ id: '3', printer: { id: '1' } }, { id: '2', printer: { id: '2' } }, { id: '1', printer: { id: '1' } }]
    expect(lastPrintByPrinter(prints)).toEqual({ 1: prints[0], 2: prints[1] })
  })
})
