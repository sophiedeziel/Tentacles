import { describe, expect, it } from 'vitest'

import { dropMove } from './SortableRows'

describe('dropMove', () => {
  const ids = ['1', '2', '3', '4']

  it('moves a row down, before the row it now sits above', () => {
    expect(dropMove(ids, '1', '3')).toEqual({ id: '1', ids: ['2', '3', '1', '4'], target: { beforeId: '4' } })
  })

  it('moves a row up, before the row it was dropped on', () => {
    expect(dropMove(ids, '4', '2')).toEqual({ id: '4', ids: ['1', '4', '2', '3'], target: { beforeId: '2' } })
    expect(dropMove(ids, '3', '1')).toEqual({ id: '3', ids: ['3', '1', '2', '4'], target: { beforeId: '1' } })
  })

  it('sends a row dropped last to the bottom', () => {
    expect(dropMove(ids, '2', '4')).toEqual({ id: '2', ids: ['1', '3', '4', '2'], target: { to: 'BOTTOM' } })
  })

  it('is null when the row did not move', () => {
    expect(dropMove(ids, '2', '2')).toBeNull()
    expect(dropMove(ids, '2', undefined)).toBeNull()
    expect(dropMove(ids, '2', '9')).toBeNull()
  })
})
