import React from 'react'
import { describe, expect, it } from 'vitest'
import { act, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { gql, InMemoryCache } from '@apollo/client'
import { App } from 'antd'

import LoadedFilament from './LoadedFilament'
import {
  CLEAR_LOADED_FILAMENT, LOADED_FILAMENT, LOADED_FILAMENT_CHANGED, SET_LOADED_FILAMENT
} from './graphql/loadedFilament'
import { POSSIBLE_TYPES, TYPE_POLICIES } from '../../Dashboard/graphql/dashboard'

const HOUR = 60 * 60 * 1000
const MATERIALS = ['PLA', 'PETG', 'ABS', 'ASA', 'TPU', 'PC', 'PA', 'PVA', 'HIPS']
const COLOURS = ['Black', 'White', 'Grey', 'Galaxy Black']
const filament = (material, colour, updatedAt = new Date(Date.now() - 2 * HOUR - 1000).toISOString()) => (
  { __typename: 'LoadedFilament', slot: 1, material, colour, updatedAt }
)
const printer = (loadedFilaments, materials = []) => ({
  __typename: 'Printer', id: '1', specs: { __typename: 'PrinterSpecs', materials }, loadedFilaments
})
const cardMock = (loadedFilaments = [], materials = []) => ({
  request: { query: LOADED_FILAMENT, variables: { printerId: '1' } },
  result: { data: { printer: printer(loadedFilaments, materials), filamentMaterials: MATERIALS, filamentColours: COLOURS } }
})
// A push from another window, after `delay` ms (by default: never during the test)
const pushed = (loadedFilaments, delay = 60000) => ({
  request: { query: LOADED_FILAMENT_CHANGED },
  result: { data: { printerStatusChanged: { __typename: 'Printer', id: '1', loadedFilaments } } },
  delay
})
const payload = (typename, loadedFilaments, errors = []) => ({
  __typename: typename, printer: { __typename: 'Printer', id: '1', loadedFilaments }, errors
})
const setMock = (input, result, delay = 20) => ({
  request: { query: SET_LOADED_FILAMENT, variables: { input: { printerId: '1', slot: 1, ...input } } },
  result: { data: { setLoadedFilament: result } },
  delay
})

const renderCard = ({ loaded = [], materials = [], mocks = [], push = pushed([]), demand } = {}) => {
  const cache = new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })
  render(
    <MockedProvider cache={cache} mocks={[cardMock(loaded, materials), push, ...mocks]}>
      <App><LoadedFilament printerId="1" demand={demand} /></App>
    </MockedProvider>
  )
  return { cache }
}

// What printerStatusChanged writes for this printer
const changeElsewhere = (cache, loadedFilaments) => act(() => {
  cache.writeFragment({
    id: 'Printer:1',
    fragment: gql`fragment ChangedElsewhere on Printer { loadedFilaments { slot material colour updatedAt } }`,
    data: { __typename: 'Printer', loadedFilaments }
  })
})

const material = () => screen.getByLabelText('Material')
const colour = () => screen.getByLabelText('Colour')
const shownMaterial = () => material().closest('.ant-select')
const updateButton = () => screen.getByRole('button', { name: /Update Filament/ })
const pick = async (option) => {
  await userEvent.click(material())
  await userEvent.click(await screen.findByTitle(option, { selector: '.ant-select-item-option' }))
}
const loadedCard = async () => {
  expect(await screen.findByRole('heading', { name: 'Loaded Filament' })).toBeInTheDocument()
  await screen.findByLabelText('Material')
}

describe('LoadedFilament', () => {
  it('starts empty when no filament is set, and enables Update once both fields have a value', async () => {
    renderCard()
    await loadedCard()
    expect(screen.getByText('No filament set')).toBeInTheDocument()
    expect(screen.getByText('Set this when you swap spools.')).toBeInTheDocument()
    expect(shownMaterial()).toHaveTextContent('Pick a material')
    expect(colour()).toHaveValue('')
    expect(screen.queryByRole('button', { name: /Remove Filament/ })).not.toBeInTheDocument()
    expect(updateButton()).toBeDisabled()

    await pick('PLA')
    expect(updateButton()).toBeDisabled()
    await userEvent.type(colour(), '   ')
    expect(updateButton()).toBeDisabled()
    await userEvent.clear(colour())
    await userEvent.type(colour(), 'Black')
    expect(updateButton()).toBeEnabled()
  })

  it('shows the loaded filament, when it was changed, and Remove Filament; Update waits for an edit', async () => {
    renderCard({ loaded: [filament('PLA', 'Galaxy Black')] })
    await loadedCard()
    expect(await screen.findByText('Updated 2 h ago')).toBeInTheDocument()
    expect(shownMaterial()).toHaveTextContent('PLA')
    expect(colour()).toHaveValue('Galaxy Black')
    expect(screen.getByRole('button', { name: /Remove Filament/ })).toBeInTheDocument()
    expect(updateButton()).toBeDisabled()

    await userEvent.type(colour(), ' 2')
    expect(updateButton()).toBeEnabled()
    // Typed back to the saved value: untouched again
    await userEvent.type(colour(), '{Backspace}{Backspace}')
    expect(updateButton()).toBeDisabled()
  })

  it('lists the materials of the printer\'s specs first', async () => {
    renderCard({ materials: ['petg', ' tpu', 'Wood'] })
    await loadedCard()
    await userEvent.click(material())
    await screen.findByTitle('PETG', { selector: '.ant-select-item-option' })
    const options = [...document.querySelectorAll('.ant-select-item-option')].map((option) => option.title)
    expect(options.slice(0, 3)).toEqual(['PETG', 'TPU', 'PLA'])
  })

  it('suggests the colours that hold what is typed', async () => {
    renderCard()
    await loadedCard()
    await userEvent.type(colour(), 'bla')
    await screen.findByTitle('Galaxy Black', { selector: '.ant-select-item-option' })
    const options = [...document.querySelectorAll('.ant-select-item-option')].map((option) => option.title)
    expect(options).toEqual(['Black', 'Galaxy Black'])
  })

  it('disables the fields and Update while saving, then says so and shows the saved filament untouched', async () => {
    renderCard({
      loaded: [filament('PLA', 'Black')],
      mocks: [setMock({ material: 'PETG', colour: 'grey ' }, payload('SetLoadedFilamentPayload', [
        filament('PETG', 'grey', new Date().toISOString())
      ]), 100)]
    })
    await loadedCard()
    await pick('PETG')
    await userEvent.clear(colour())
    await userEvent.type(colour(), 'grey ')
    await userEvent.click(updateButton())

    expect(updateButton()).toBeDisabled()
    expect(updateButton()).toHaveClass('ant-btn-loading')
    expect(colour()).toBeDisabled()
    expect(material()).toBeDisabled()

    expect(await screen.findByText('Filament updated')).toBeInTheDocument()
    expect(colour()).toHaveValue('grey') // as the server saved it
    expect(shownMaterial()).toHaveTextContent('PETG')
    expect(screen.getByText('Updated just now')).toBeInTheDocument()
    expect(updateButton()).toBeDisabled()
    expect(colour()).toBeEnabled()
    expect(screen.queryByText(/in another window/)).not.toBeInTheDocument()
  })

  it('shows what the server refused under its field, and keeps the values', async () => {
    const tooLong = 'x'.repeat(41)
    renderCard({
      loaded: [filament('PLA', 'Black')],
      mocks: [setMock({ material: 'PLA', colour: tooLong }, payload('SetLoadedFilamentPayload', [filament('PLA', 'Black')], [
        { __typename: 'UserError', field: 'colour', message: 'Colour is too long (maximum is 40 characters)' }
      ]))]
    })
    await loadedCard()
    await userEvent.clear(colour())
    await userEvent.type(colour(), tooLong)
    await userEvent.click(updateButton())

    expect(await screen.findByText('Colour is too long (maximum is 40 characters)')).toBeInTheDocument()
    expect(colour().closest('.ant-form-item')).toHaveClass('ant-form-item-has-error')
    expect(colour()).toHaveValue(tooLong)
    expect(updateButton()).toBeEnabled()
    expect(screen.queryByText('Filament updated')).not.toBeInTheDocument()

    // Gone once the field changes
    await userEvent.type(colour(), '{Backspace}')
    expect(colour().closest('.ant-form-item')).not.toHaveClass('ant-form-item-has-error')
  })

  it('shows an error that concerns no field as a message', async () => {
    renderCard({
      mocks: [setMock({ material: 'PLA', colour: 'Black' }, {
        __typename: 'SetLoadedFilamentPayload', printer: null, errors: [{ __typename: 'UserError', field: null, message: 'Printer not found' }]
      })]
    })
    await loadedCard()
    await pick('PLA')
    await userEvent.type(colour(), 'Black')
    await userEvent.click(updateButton())
    expect(await screen.findByText('Printer not found')).toBeInTheDocument()
    expect(colour()).toHaveValue('Black')
  })

  it('removes the filament without asking', async () => {
    renderCard({
      loaded: [filament('PLA', 'Black')],
      mocks: [{
        request: { query: CLEAR_LOADED_FILAMENT, variables: { input: { printerId: '1', slot: 1 } } },
        result: { data: { clearLoadedFilament: payload('ClearLoadedFilamentPayload', []) } }
      }]
    })
    await loadedCard()
    await userEvent.click(screen.getByRole('button', { name: /Remove Filament/ }))
    expect(await screen.findByText('Filament removed')).toBeInTheDocument()
    expect(screen.getByText('No filament set')).toBeInTheDocument()
    expect(colour()).toHaveValue('')
    expect(screen.queryByRole('button', { name: /Remove Filament/ })).not.toBeInTheDocument()
    expect(updateButton()).toBeDisabled()
  })

  describe('changed in another window', () => {
    it('takes the pushed filament when untouched', async () => {
      renderCard({ loaded: [filament('PLA', 'Black')], push: pushed([filament('PETG', 'Grey')], 300) })
      await loadedCard()
      expect(colour()).toHaveValue('Black')
      await waitFor(() => expect(colour()).toHaveValue('Grey'))
      expect(shownMaterial()).toHaveTextContent('PETG')
      expect(updateButton()).toBeDisabled()
      expect(screen.queryByText(/in another window/)).not.toBeInTheDocument()
    })

    it('takes a removal when untouched', async () => {
      const { cache } = renderCard({ loaded: [filament('PLA', 'Black')] })
      await loadedCard()
      changeElsewhere(cache, [])
      expect(await screen.findByText('No filament set')).toBeInTheDocument()
      expect(colour()).toHaveValue('')
      expect(screen.queryByRole('button', { name: /Remove Filament/ })).not.toBeInTheDocument()
    })

    it('keeps the edits and says what it changed to when edited', async () => {
      const { cache } = renderCard({ loaded: [filament('PLA', 'Black')] })
      await loadedCard()
      await userEvent.type(colour(), ' Matte')
      changeElsewhere(cache, [filament('PETG', 'Grey')])

      expect(await screen.findByText('Changed to PETG · Grey in another window')).toBeInTheDocument()
      expect(colour()).toHaveValue('Black Matte')
      expect(shownMaterial()).toHaveTextContent('PLA')
      expect(updateButton()).toBeEnabled()
    })

    it('keeps the edits and says it was removed when edited', async () => {
      const { cache } = renderCard({ loaded: [filament('PLA', 'Black')] })
      await loadedCard()
      await pick('ABS')
      changeElsewhere(cache, [])
      expect(await screen.findByText('Removed in another window')).toBeInTheDocument()
      expect(shownMaterial()).toHaveTextContent('ABS')
      expect(colour()).toHaveValue('Black')
    })
  })

  describe('with the global queue on', () => {
    // How many waiting jobs ask for each loaded filament (the printer page's queue query)
    const asking = (material, colour, waitingJobsAskingCount) => [{ slot: 1, material, colour, waitingJobsAskingCount }]

    it('says when no waiting job asks for the loaded filament', async () => {
      renderCard({ loaded: [filament('PLA', 'White')], demand: asking('PLA', 'White', 0) })
      await loadedCard()
      expect(screen.getByText('No waiting job asks for PLA White. Any Colour jobs still match.')).toBeInTheDocument()
    })

    it('counts the waiting jobs that ask for it', async () => {
      renderCard({ loaded: [filament('PLA', 'White')], demand: asking('PLA', 'White', 3) })
      await loadedCard()
      expect(screen.getByText('3 waiting jobs ask for PLA White.')).toBeInTheDocument()
    })

    it('never shows a count for another filament (changed since)', async () => {
      renderCard({ loaded: [filament('PLA', 'Black')], demand: asking('PLA', 'White', 3) })
      await loadedCard()
      expect(screen.queryByText(/waiting job/)).not.toBeInTheDocument()
    })

    it('says nothing without a loaded filament', async () => {
      renderCard({ demand: [] })
      await loadedCard()
      expect(screen.getByText('No filament set')).toBeInTheDocument()
      expect(screen.queryByText(/waiting job/)).not.toBeInTheDocument()
    })

    it('says nothing while the queue is off (no demand)', async () => {
      renderCard({ loaded: [filament('PLA', 'White')] })
      await loadedCard()
      expect(await screen.findByText('Updated 2 h ago')).toBeInTheDocument()
      expect(screen.queryByText(/waiting job/)).not.toBeInTheDocument()
    })
  })
})
