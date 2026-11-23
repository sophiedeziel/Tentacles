import { describe, expect, it } from 'vitest'

import { bedBannerView, jobSizeText, needsLines, skippedSummary, takesJobsText } from './printerQueueView'
import { printOnBed } from './printerQueueFixtures'

const UNTIL_CLEARED = 'This printer takes no new job until you confirm the bed is clear.'

describe('bedBannerView', () => {
  it('names the finished copy on the bed', () => {
    expect(bedBannerView(printOnBed())).toEqual({
      title: 'Print finished: remove the part',
      text: `bracket.gcode · copy 2 of 10 is done. ${UNTIL_CLEARED}`
    })
  })

  it('names a single print by its file alone', () => {
    const single = { ...printOnBed(), printJob: { ...printOnBed().printJob, copies: 1 } }
    expect(bedBannerView(single).text).toBe(`bracket.gcode is done. ${UNTIL_CLEARED}`)
  })

  it('says when the print failed or was cancelled', () => {
    expect(bedBannerView(printOnBed('FAILED'))).toEqual({
      title: 'Print failed: remove the part',
      text: `bracket.gcode · copy 2 of 10 failed. ${UNTIL_CLEARED}`
    })
    expect(bedBannerView(printOnBed('CANCELLED'))).toEqual({
      title: 'Print cancelled: remove the part',
      text: `bracket.gcode · copy 2 of 10 was cancelled. ${UNTIL_CLEARED}`
    })
  })

  it('says the last print when it is not known', () => {
    expect(bedBannerView(null)).toEqual({ title: 'Remove the last print', text: UNTIL_CLEARED })
  })
})

describe('jobSizeText', () => {
  it('gives a batch\'s size and copies left to start, or 1 print', () => {
    expect(jobSizeText({ copies: 10, copiesLeftToStart: 7 })).toBe('Batch of 10 · 7 left to start')
    expect(jobSizeText({ copies: 1, copiesLeftToStart: 1 })).toBe('1 print')
  })
})

describe('needsLines', () => {
  const needs = (more) => ({ pending: false, known: true, colour: null, filaments: [], footprint: null, ...more })

  it('says each tool\'s material and colour', () => {
    expect(needsLines(needs({ filaments: [{ tool: 0, material: 'PLA', colour: 'Black' }] }))).toEqual(['PLA · Black'])
    expect(needsLines(needs({
      filaments: [{ tool: 0, material: 'PETG', colour: null }, { tool: 1, material: 'PLA', colour: null }]
    }))).toEqual(['T0 PETG · Any colour', 'T1 PLA · Any colour'])
  })

  it('says when the G-code is being read or its needs are not known', () => {
    expect(needsLines(needs({ pending: true }))).toEqual(['Reading the G-code'])
    expect(needsLines(needs({ known: false }))).toEqual(['Not known'])
  })
})

describe('skippedSummary', () => {
  it('counts the jobs it skips', () => {
    expect(skippedSummary(1)).toBe("1 job it can't take, and why")
    expect(skippedSummary(3)).toBe("3 jobs it can't take, and why")
  })
})

describe('takesJobsText', () => {
  it('says whether it takes jobs from the queue', () => {
    expect(takesJobsText(true)).toBe('Taking jobs from the queue')
    expect(takesJobsText(false)).toBe('Not taking jobs')
  })
})
