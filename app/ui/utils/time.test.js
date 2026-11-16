import { describe, expect, it } from 'vitest'
import { doneAt, formatAgo, formatClock, formatTimeLeft } from './time'

describe('time', () => {
  it('adds the time left to the snapshot time', () => {
    expect(doneAt('2026-11-14T13:23:00Z', 'PT1H12M').toISOString()).toBe('2026-11-14T14:35:00.000Z')
  })

  it('has no finish time without a time left', () => {
    expect(doneAt('2026-11-14T13:23:00Z', null)).toBeNull()
    expect(doneAt(null, 'PT5M')).toBeNull()
  })

  it('formats the time left in hours and minutes', () => {
    expect(formatTimeLeft(72 * 60 * 1000)).toBe('1 h 12 min')
    expect(formatTimeLeft(185 * 60 * 1000)).toBe('3 h 05 min')
    expect(formatTimeLeft(52 * 60 * 1000)).toBe('52 min')
    expect(formatTimeLeft(10 * 1000)).toBe('< 1 min')
    expect(formatTimeLeft(-5000)).toBe('< 1 min')
  })

  it('formats a clock time on 24 hours', () => {
    expect(formatClock(new Date(2026, 10, 14, 14, 35))).toBe('14:35')
  })

  it('formats how long ago something happened', () => {
    const now = '2026-11-14T19:00:00Z'
    expect(formatAgo('2026-11-14T18:59:30Z', now)).toBe('just now')
    expect(formatAgo('2026-11-14T18:55:00Z', now)).toBe('5 min ago')
    expect(formatAgo('2026-11-14T17:00:00Z', now)).toBe('2 h ago')
    expect(formatAgo('2026-11-11T19:00:00Z', now)).toBe('3 d ago')
  })
})
