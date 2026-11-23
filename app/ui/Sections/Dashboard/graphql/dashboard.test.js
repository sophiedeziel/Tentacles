import { describe, expect, it } from 'vitest'
import { gql, InMemoryCache } from '@apollo/client'

import { POSSIBLE_TYPES, TYPE_POLICIES } from './dashboard'

// The printer page's queue query selects the count; the Loaded Filament card (and its printerStatusChanged push)
// doesn't
const WITH_COUNT = gql`
  fragment WithCount on Printer { id loadedFilaments { slot material colour waitingJobsAskingCount } }
`
const WITHOUT_COUNT = gql`
  fragment WithoutCount on Printer { id loadedFilaments { slot material colour updatedAt } }
`
const UPDATED_AT = '2026-11-20T12:00:00Z'
const filament = (slot, material, colour, extra) => ({ __typename: 'LoadedFilament', slot, material, colour, ...extra })

const cacheWithCounts = (loadedFilaments) => {
  const cache = new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })
  cache.writeFragment({ id: 'Printer:1', fragment: WITH_COUNT, data: { __typename: 'Printer', id: '1', loadedFilaments } })
  return cache
}
const push = (cache, loadedFilaments) => cache.writeFragment({
  id: 'Printer:1', fragment: WITHOUT_COUNT, data: { __typename: 'Printer', id: '1', loadedFilaments }
})
const counted = (cache) => cache.readFragment({ id: 'Printer:1', fragment: WITH_COUNT, returnPartialData: true })
  .loadedFilaments

describe('TYPE_POLICIES: Printer.loadedFilaments', () => {
  it('keeps the count of a filament sent again unchanged, by a selection without it', () => {
    const cache = cacheWithCounts([filament(1, 'PLA', 'White', { waitingJobsAskingCount: 3 })])
    push(cache, [filament(1, 'PLA', 'White', { updatedAt: UPDATED_AT })])

    expect(counted(cache)).toEqual([filament(1, 'PLA', 'White', { waitingJobsAskingCount: 3 })])
    expect(cache.readFragment({ id: 'Printer:1', fragment: WITHOUT_COUNT }).loadedFilaments)
      .toEqual([filament(1, 'PLA', 'White', { updatedAt: UPDATED_AT })])
  })

  it('drops the count of a changed filament: it was for the old one', () => {
    const cache = cacheWithCounts([filament(1, 'PLA', 'White', { waitingJobsAskingCount: 3 })])
    push(cache, [filament(1, 'PLA', 'Black', { updatedAt: UPDATED_AT })])

    expect(counted(cache)).toEqual([{ __typename: 'LoadedFilament', slot: 1, material: 'PLA', colour: 'Black' }])
    // The queue query's data is incomplete: it refetches
    expect(cache.readFragment({ id: 'Printer:1', fragment: WITH_COUNT })).toBeNull()
  })

  it('still replaces the list whole: a removed filament disappears, the order is the incoming one', () => {
    const cache = cacheWithCounts([
      filament(1, 'PLA', 'White', { waitingJobsAskingCount: 3 }),
      filament(2, 'PETG', 'Black', { waitingJobsAskingCount: 1 })
    ])
    push(cache, [filament(2, 'PETG', 'Black', { updatedAt: UPDATED_AT })])
    expect(counted(cache)).toEqual([filament(2, 'PETG', 'Black', { waitingJobsAskingCount: 1 })])

    push(cache, [])
    expect(counted(cache)).toEqual([])
  })
})
