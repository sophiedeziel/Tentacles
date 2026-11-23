import { describe, expect, it } from 'vitest'

import { copiesDialog, effectText, floorText } from './copiesText'

const copy = (status) => ({ status, result: status === 'COMPLETED' ? 'COMPLETED' : null })
// bracket_v3.gcode × 10: 2 done, 1 printing, 7 waiting
const BATCH = {
  id: '1', copies: 10, copiesLeftToStart: 7, file: { filename: 'bracket_v3.gcode' },
  prints: [copy('COMPLETED'), copy('COMPLETED'), copy('ACTIVE')]
}
const SINGLE = { id: '2', copies: 1, copiesLeftToStart: 1, file: { filename: 'gear_housing.gcode' }, prints: [] }

describe('copiesDialog', () => {
  it('changes the number of copies of a batch, never below the copies done and printing', () => {
    expect(copiesDialog(BATCH, 7)).toEqual({
      title: 'Change the number of copies of bracket_v3.gcode',
      min: 3,
      change: 'Removes 3 copies from the 7 waiting. 4 stay in the queue.',
      note: 'The lowest is 3: 2 copies are done and 1 is printing, and those can\'t be taken back. To stop the copy ' +
        'that is printing, use Cancel Print in its row\'s menu.',
      ok: 'Set to 7 Copies',
      keep: 'Keep 10 Copies',
      unchanged: false
    })
    expect(copiesDialog(BATCH, 10).unchanged).toBe(true)
  })

  it('prints more copies of a single print, which becomes a batch', () => {
    expect(copiesDialog(SINGLE, 3)).toEqual({
      title: 'Print more copies of gear_housing.gcode',
      min: 2,
      change: 'Now 1 copy. 2 more will be added.',
      note: 'The job becomes a batch. The added copies keep its filament, printers and place in the queue.',
      ok: 'Print 3 Copies',
      keep: 'Keep 1 Copy',
      unchanged: false
    })
  })
})

describe('effectText', () => {
  it('says what the new number does to the waiting copies', () => {
    expect(effectText(BATCH, 10)).toBe('No change.')
    expect(effectText(BATCH, 12)).toBe('Adds 2 copies to the 7 waiting.')
    expect(effectText(BATCH, 9)).toBe('Removes 1 copy from the 7 waiting. 6 stay in the queue.')
    expect(effectText(BATCH, 3)).toBe('Removes all 7 waiting copies. The copy that is printing finishes.')
  })
})

describe('floorText', () => {
  it('says why the floor is where it is, and nothing when no copy started', () => {
    expect(floorText({ ...BATCH, prints: [copy('COMPLETED')], copiesLeftToStart: 9 }))
      .toBe('The lowest is 1: 1 copy is done, and it can\'t be taken back.')
    expect(floorText({ ...BATCH, prints: [], copiesLeftToStart: 10 })).toBeNull()
  })
})
