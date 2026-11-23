import { describe, expect, it } from 'vitest'

import whatHappensNext, { WAITING_FILTERS, WHAT_HAPPENS_NEXT_KINDS, matchesFilter } from './whatHappensNext'

const MK4 = { id: '1', name: 'Prusa MK4' }
const ENDER = { id: '2', name: 'Ender 3 V2' }
const PLA_WHITE = { known: true, pending: false, filaments: [{ tool: 0, material: 'PLA', colour: 'White' }] }

// A waiting job: one copy, two printers can print it, `kind` (for `printer`) next
const job = (kind, printer = null, { next = {}, ...more } = {}) => ({
  copies: 1,
  copiesLeftToStart: 1,
  samePrinter: false,
  eligiblePrinters: [MK4, ENDER],
  needs: PLA_WHITE,
  whatHappensNext: { kind, printer, jobsAhead: 0, dispatchPaused: false, ...next },
  ...more
})
const paused = { dispatchPaused: true }
const say = (...args) => whatHappensNext(job(...args))?.text
const batch = { copies: 10, copiesLeftToStart: 7 }
const sameBatch = { copies: 2, copiesLeftToStart: 2, samePrinter: true }

describe('whatHappensNext', () => {
  it('knows every WhatHappensNextKind of the schema', () => {
    expect(WHAT_HAPPENS_NEXT_KINDS).toEqual([
      'ON_HOLD', 'BLOCKED', 'NEXT_READY_PRINTER', 'BATCH_FIRST_READY_PRINTER', 'STARTING', 'AFTER_BED_CLEARED',
      'AFTER_CURRENT_PRINT', 'BATCH_ON_PRINTER'
    ])
  })

  it.each([
    ['ON_HOLD', null, 'On hold', 'held'],
    ['NEXT_READY_PRINTER', null, 'Goes to the next ready printer', 'waiting'],
    ['STARTING', MK4, 'Starting on Prusa MK4', 'next'],
    ['AFTER_BED_CLEARED', ENDER, 'Ender 3 V2 takes it once its bed is cleared', 'next'],
    ['AFTER_CURRENT_PRINT', MK4, 'Prusa MK4 takes it when its print finishes', 'waiting'],
    ['BLOCKED', null, 'Blocked: no printer has PLA White loaded.', 'blocked']
  ])('says %s as words, with its mark', (kind, printer, text, icon) => {
    expect(whatHappensNext(job(kind, printer))).toEqual({ text, icon, loadFilament: kind === 'BLOCKED' })
  })

  it('says what a batch takes', () => {
    expect(say('AFTER_BED_CLEARED', ENDER, batch)).toBe('Ender 3 V2 takes the next copy once its bed is cleared')
    expect(say('AFTER_CURRENT_PRINT', MK4, batch)).toBe('Prusa MK4 takes the next copy when its print finishes')
    expect(say('NEXT_READY_PRINTER', null, batch)).toBe('Each goes to the next ready printer')
    expect(say('BATCH_ON_PRINTER', MK4, { copies: 10, copiesLeftToStart: 7, samePrinter: true }))
      .toBe('Prusa MK4 prints copy 4 when copy 3 finishes')
  })

  it('says a bound batch waits for its printer’s print when none of its copies is printing', () => {
    const bound = { copies: 3, copiesLeftToStart: 2, samePrinter: true, prints: [{ status: 'COMPLETED' }] }
    expect(say('BATCH_ON_PRINTER', MK4, bound)).toBe('Prusa MK4 prints copy 2 when its print finishes')
    expect(whatHappensNext(job('BATCH_ON_PRINTER', MK4, bound), { printerId: MK4.id }).text)
      .toBe('Prints copy 2 when the current print finishes')
  })

  it('says a same-printer batch goes whole to the printer lined up for it', () => {
    expect(say('AFTER_BED_CLEARED', ENDER, sameBatch)).toBe('Ender 3 V2 takes both copies once its bed is cleared')
    expect(say('AFTER_CURRENT_PRINT', MK4, { ...sameBatch, copies: 4, copiesLeftToStart: 4 }))
      .toBe('Prusa MK4 takes all 4 copies when its print finishes')
    expect(say('BATCH_FIRST_READY_PRINTER', null, sameBatch)).toBe('The first ready printer takes both copies')
  })

  it('counts the jobs the printer takes first', () => {
    expect(say('AFTER_CURRENT_PRINT', MK4, { next: { jobsAhead: 1 } })).toBe('Prusa MK4, after 1 job ahead of it')
    expect(say('AFTER_CURRENT_PRINT', MK4, { next: { jobsAhead: 3 } })).toBe('Prusa MK4, after 3 jobs ahead of it')
  })

  it('says it waits for dispatch to resume while dispatch is paused', () => {
    expect(say('AFTER_BED_CLEARED', ENDER, { ...batch, next: paused }))
      .toBe('Ready for Ender 3 V2 when dispatch resumes and its bed is cleared')
    expect(say('AFTER_CURRENT_PRINT', MK4, { next: paused }))
      .toBe('Waiting for dispatch to resume, then for Prusa MK4 to finish its print')
    expect(say('AFTER_CURRENT_PRINT', MK4, { next: { ...paused, jobsAhead: 1 } }))
      .toBe('Waiting for dispatch to resume. Prusa MK4, after 1 job ahead of it')
    expect(say('STARTING', MK4, { next: paused })).toBe('Ready for Prusa MK4 when dispatch resumes')
    expect(say('NEXT_READY_PRINTER', null, { ...batch, next: paused }))
      .toBe('Waiting for dispatch to resume, then each goes to the next ready printer')
    expect(say('BATCH_ON_PRINTER', MK4, { ...batch, samePrinter: true, next: paused }))
      .toBe('Waiting for dispatch to resume, then for Prusa MK4 to finish copy 3')
  })

  it('keeps the mark of what it waits for while dispatch is paused', () => {
    expect(whatHappensNext(job('AFTER_BED_CLEARED', ENDER, { next: paused })).icon).toBe('next')
    expect(whatHappensNext(job('AFTER_CURRENT_PRINT', MK4, { next: paused })).icon).toBe('waiting')
  })

  it('says blocked and held the same whether dispatch runs or not', () => {
    expect(say('BLOCKED', null, { next: paused })).toBe('Blocked: no printer has PLA White loaded.')
    expect(say('ON_HOLD', null, { next: paused })).toBe('On hold')
  })

  it('names every filament no printer has loaded, without "Any colour"', () => {
    const needs = {
      known: true,
      filaments: [{ tool: 0, material: 'PLA', colour: 'White' }, { tool: 1, material: 'PETG', colour: null }]
    }
    expect(say('BLOCKED', null, { needs })).toBe('Blocked: no printer has PLA White and PETG loaded.')
    expect(say('BLOCKED', null, { needs: { known: false, filaments: [] } }))
      .toBe('Blocked: no printer has its filament loaded.')
  })

  it('says no printer can print a blocked job without eligible printers, with nothing to load', () => {
    expect(whatHappensNext(job('BLOCKED', null, { eligiblePrinters: [] })))
      .toEqual({ text: 'Blocked: no printer can print it.', icon: 'blocked', loadFilament: false })
  })

  it('says it from the page of the printer it names', () => {
    const own = (kind, more) => whatHappensNext(job(kind, MK4, more), { printerId: MK4.id }).text
    expect(own('AFTER_BED_CLEARED')).toBe('Starts once the bed is cleared')
    expect(own('AFTER_BED_CLEARED', { ...batch, next: paused })).toBe('Starts when dispatch resumes and the bed is cleared')
    expect(own('AFTER_CURRENT_PRINT')).toBe('Starts when the current print finishes')
    expect(own('AFTER_CURRENT_PRINT', { next: { jobsAhead: 2 } })).toBe('After 2 jobs ahead of it')
    expect(own('STARTING')).toBe('Starting')
    expect(own('BATCH_ON_PRINTER', batch)).toBe('Prints copy 4 when copy 3 finishes')
    expect(whatHappensNext(job('ON_HOLD'), { printerId: MK4.id }).text).toBe('On hold until released')
  })

  it('names another printer the same way from a printer page', () => {
    expect(whatHappensNext(job('AFTER_BED_CLEARED', ENDER), { printerId: MK4.id }).text)
      .toBe('Ender 3 V2 takes it once its bed is cleared')
  })

  it('names "A printer" when the printer a kind names is missing', () => {
    expect(say('STARTING')).toBe('Starting on A printer')
  })

  it('says nothing when nothing is left to happen, or for a kind it does not know', () => {
    expect(whatHappensNext(job('SOMETHING_NEW'))).toBeNull()
    expect(whatHappensNext({ ...job('STARTING'), whatHappensNext: null })).toBeNull()
  })
})

describe('matchesFilter', () => {
  const jobs = ['ON_HOLD', 'BLOCKED', 'NEXT_READY_PRINTER', 'AFTER_BED_CLEARED', 'AFTER_CURRENT_PRINT']
    .map((kind) => job(kind, MK4))
  const shown = (filter) => jobs.filter((each) => matchesFilter(each, filter)).map((each) => each.whatHappensNext.kind)

  it('filters by what happens next', () => {
    expect(WAITING_FILTERS).toEqual(['All', 'Ready', 'Blocked', 'On Hold'])
    expect(shown('All')).toHaveLength(5)
    expect(shown('Ready')).toEqual(['NEXT_READY_PRINTER', 'AFTER_BED_CLEARED', 'AFTER_CURRENT_PRINT'])
    expect(shown('Blocked')).toEqual(['BLOCKED'])
    expect(shown('On Hold')).toEqual(['ON_HOLD'])
  })
})
