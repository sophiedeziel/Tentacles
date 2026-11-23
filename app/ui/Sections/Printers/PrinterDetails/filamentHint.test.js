import { describe, expect, it } from 'vitest'

import filamentHint from './filamentHint'

const PLA_WHITE = { slot: 1, material: 'PLA', colour: 'White' }

describe('filamentHint', () => {
  it('says no waiting job asks for the filament, and that Any Colour jobs still match', () => {
    expect(filamentHint(PLA_WHITE, 0)).toBe('No waiting job asks for PLA White. Any Colour jobs still match.')
  })

  it('counts the waiting jobs that ask for it', () => {
    expect(filamentHint(PLA_WHITE, 1)).toBe('PLA White matches 1 waiting job.')
    expect(filamentHint(PLA_WHITE, 3)).toBe('PLA White matches 3 waiting jobs.')
  })

  it('says nothing when the count is not known', () => {
    expect(filamentHint(PLA_WHITE, null)).toBeNull()
    expect(filamentHint(PLA_WHITE, undefined)).toBeNull()
  })
})
