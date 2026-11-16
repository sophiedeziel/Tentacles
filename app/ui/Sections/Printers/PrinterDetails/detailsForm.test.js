import { describe, expect, it } from 'vitest'

import { formValues, hasChanges, updateInput } from './detailsForm'

const PRUSA = { id: '4', name: 'Prusa MK4', backend: 'PRUSALINK', uri: 'http://192.168.1.21', username: 'maker' }
const OCTO = { id: '1', name: 'Ender 3', backend: 'OCTOPRINT', uri: 'http://192.168.1.57', username: null }

describe('detailsForm', () => {
  it('starts from the saved printer, with a blank secret', () => {
    expect(formValues(PRUSA)).toEqual({ name: 'Prusa MK4', uri: 'http://192.168.1.21', username: 'maker', secret: '' })
    expect(formValues(OCTO)).toEqual({ name: 'Ender 3', uri: 'http://192.168.1.57', username: '', secret: '' })
  })

  it('sends nothing when nothing changed', () => {
    expect(updateInput(PRUSA, formValues(PRUSA))).toEqual({})
    expect(hasChanges(PRUSA, formValues(PRUSA))).toBe(false)
    expect(hasChanges(PRUSA, undefined)).toBe(false)
  })

  it('sends only the changed fields', () => {
    expect(updateInput(PRUSA, { ...formValues(PRUSA), uri: 'http://192.168.1.22' })).toEqual({ uri: 'http://192.168.1.22' })
    expect(updateInput(PRUSA, { ...formValues(PRUSA), username: '' })).toEqual({ username: '' })
  })

  it('sends the secret only when one was typed', () => {
    expect(updateInput(PRUSA, { ...formValues(PRUSA), secret: 'new pass' })).toEqual({ secret: 'new pass' })
    expect(hasChanges(PRUSA, { ...formValues(PRUSA), secret: 'x' })).toBe(true)
  })

  it('never sends a username for OctoPrint', () => {
    expect(updateInput(OCTO, { ...formValues(OCTO), username: 'someone' })).toEqual({})
  })
})
