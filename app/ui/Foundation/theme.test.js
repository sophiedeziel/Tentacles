import { describe, expect, it } from 'vitest'
import { STATE_FAMILIES, STATE_PALETTE, statePalette } from './theme'

describe('theme', () => {
  it('has a colour, a tint and a tag colour for every state family', () => {
    STATE_FAMILIES.forEach((family) => {
      expect(STATE_PALETTE[family]).toEqual({
        color: expect.stringMatching(/^#[0-9a-f]{6}$/),
        tint: expect.stringMatching(/^#[0-9a-f]{6}$/),
        tag: expect.any(String)
      })
    })
  })

  it('prints in purple, is ready in green, paused in amber and in error in red', () => {
    expect(statePalette('PRINTING').color).toBe('#722ed1')
    expect(statePalette('OPERATIONAL').color).toBe('#52c41a')
    expect(statePalette('PAUSED').color).toBe('#faad14')
    expect(statePalette('ERROR').color).toBe('#ff4d4f')
  })

  it('reads an unknown state family as offline', () => {
    expect(statePalette('SOMETHING_NEW')).toBe(STATE_PALETTE.OFFLINE)
    expect(statePalette(undefined)).toBe(STATE_PALETTE.OFFLINE)
  })
})
