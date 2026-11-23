import { describe, expect, it } from 'vitest'

import whatHappensNext, { WHAT_HAPPENS_NEXT_KINDS } from './whatHappensNext'

const MK4 = { id: '1', name: 'Prusa MK4' }
const next = (kind, printer = null) => ({ kind, printer })

describe('whatHappensNext', () => {
  it('knows every WhatHappensNextKind of the schema', () => {
    expect(WHAT_HAPPENS_NEXT_KINDS).toEqual([
      'ON_HOLD', 'DISPATCH_PAUSED', 'BLOCKED', 'NEXT_READY_PRINTER', 'AFTER_CURRENT_PRINT', 'AFTER_BED_CLEARED',
      'STARTING', 'BATCH_ON_PRINTER', 'BATCH_FIRST_READY_PRINTER'
    ])
  })

  it.each([
    ['ON_HOLD', null, 'On hold', 'held'],
    ['DISPATCH_PAUSED', null, 'Dispatch paused', 'paused'],
    ['NEXT_READY_PRINTER', null, 'Goes to the next ready printer', 'plain'],
    ['AFTER_CURRENT_PRINT', MK4, 'Prusa MK4 takes it when its print finishes', 'plain'],
    ['AFTER_BED_CLEARED', MK4, 'Prusa MK4 takes it once its bed is cleared', 'plain'],
    ['STARTING', MK4, 'Starting on Prusa MK4', 'plain'],
    ['BATCH_ON_PRINTER', MK4, 'Prusa MK4 prints the next copy when the current one finishes', 'plain'],
    ['BATCH_FIRST_READY_PRINTER', null, 'The first ready printer takes all the copies', 'plain']
  ])('says %s as words', (kind, printer, text, tone) => {
    expect(whatHappensNext(next(kind, printer), { eligibleCount: 1 })).toEqual({ text, tone, loadFilament: false })
  })

  it('says each copy of a batch goes to the next ready printer', () => {
    expect(whatHappensNext(next('NEXT_READY_PRINTER'), { copiesLeft: 4 }).text)
      .toBe('Each copy goes to the next ready printer')
  })

  it('offers Load Filament when a blocked job has printers that could print it', () => {
    expect(whatHappensNext(next('BLOCKED'), { eligibleCount: 2 }))
      .toEqual({ text: 'No printer has the needed filament loaded', tone: 'blocked', loadFilament: true })
  })

  it('says no printer can print a blocked job without eligible printers, with nothing to load', () => {
    expect(whatHappensNext(next('BLOCKED'), { eligibleCount: 0 }))
      .toEqual({ text: 'No printer can print it', tone: 'blocked', loadFilament: false })
  })

  it('names "A printer" when the printer a kind names is missing', () => {
    expect(whatHappensNext(next('STARTING')).text).toBe('Starting on A printer')
  })

  it('says nothing when nothing is left to happen, or for a kind it does not know', () => {
    expect(whatHappensNext(null)).toBeNull()
    expect(whatHappensNext(next('SOMETHING_NEW'))).toBeNull()
  })
})
