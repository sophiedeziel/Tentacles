import { describe, expect, it } from 'vitest'

import { firmwareOptions, formValues, hasChanges, specsFormValues, updateInput, volumeInput } from './detailsForm'

const PRUSA = { id: '4', name: 'Prusa MK4', backend: 'PRUSALINK', uri: 'http://192.168.1.21', username: 'maker' }
const OCTO = { id: '1', name: 'Ender 3', backend: 'OCTOPRINT', uri: 'http://192.168.1.57', username: null }
const MK4_SPECS = {
  brand: 'Prusa Research',
  model: 'MK4',
  firmwareDisplayName: 'prusa_firmware',
  firmwareVersion: '6.2.0',
  buildVolume: { x: 250, y: 210, z: 220 },
  extruders: 1,
  nozzleDiameter: 0.6,
  maxHotendTemp: 290,
  maxBedTemp: 120,
  heatedBed: true,
  heatedChamber: false,
  webcam: null,
  materials: ['PLA', 'PETG']
}
const MK4 = { ...PRUSA, specs: MK4_SPECS }
const KOSSEL = { ...OCTO, specs: { buildVolume: { diameter: 230, height: 300 }, materials: [] } }
const NO_SPECS = { ...OCTO, specs: { materials: [] } }

// The form's values with some specs changed
const editing = (printer, specs) => {
  const values = formValues(printer)
  return { ...values, specs: { ...values.specs, ...specs } }
}

describe('detailsForm', () => {
  it('starts from the saved printer, with a blank secret', () => {
    expect(formValues(PRUSA)).toMatchObject({ name: 'Prusa MK4', uri: 'http://192.168.1.21', username: 'maker', secret: '' })
    expect(formValues(OCTO)).toMatchObject({ name: 'Ender 3', uri: 'http://192.168.1.57', username: '', secret: '' })
  })

  it('sends nothing when nothing changed', () => {
    expect(updateInput(PRUSA, formValues(PRUSA))).toEqual({})
    expect(updateInput(MK4, formValues(MK4))).toEqual({})
    expect(updateInput(KOSSEL, formValues(KOSSEL))).toEqual({})
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

  describe('specs', () => {
    it('reads the saved specs, with the bed shape of the build volume', () => {
      expect(formValues(MK4).specs).toEqual({
        brand: 'Prusa Research',
        model: 'MK4',
        firmware: 'prusa_firmware',
        firmwareVersion: '6.2.0',
        bedShape: 'rectangular',
        x: 250,
        y: 210,
        z: 220,
        diameter: null,
        extruders: 1,
        nozzleDiameter: 0.6,
        maxHotendTemp: 290,
        maxBedTemp: 120,
        heatedBed: true,
        heatedChamber: false,
        webcam: null,
        materials: ['PLA', 'PETG']
      })
      expect(formValues(KOSSEL).specs).toMatchObject({ bedShape: 'circular', diameter: 230, z: 300, x: null, y: null })
      expect(specsFormValues({})).toMatchObject({ bedShape: 'rectangular', brand: null, materials: [] })
    })

    it('sends only the changed specs, and null for a cleared one', () => {
      expect(updateInput(MK4, editing(MK4, { nozzleDiameter: 0.4, model: '' }))).toEqual({ specs: { nozzleDiameter: 0.4, model: null } })
      expect(updateInput(MK4, editing(MK4, { firmware: 'Smoothie', materials: ['PLA'] })))
        .toEqual({ specs: { firmware: 'Smoothie', materials: ['PLA'] } })
      expect(updateInput(MK4, editing(MK4, { firmware: null, maxBedTemp: null }))).toEqual({ specs: { firmware: null, maxBedTemp: null } })
      expect(updateInput(NO_SPECS, editing(NO_SPECS, { brand: '', webcam: false, heatedBed: null })))
        .toEqual({ specs: { webcam: false } })
    })

    it('sends the build volume once every dimension of its shape is filled', () => {
      expect(updateInput(MK4, editing(MK4, { z: 250 }))).toEqual({ specs: { buildVolume: { rectangular: { x: 250, y: 210, z: 250 } } } })
      expect(updateInput(NO_SPECS, editing(NO_SPECS, { x: 200, y: 200 }))).toEqual({})
      expect(updateInput(NO_SPECS, editing(NO_SPECS, { bedShape: 'circular', diameter: 180, z: 300 })))
        .toEqual({ specs: { buildVolume: { circular: { diameter: 180, height: 300 } } } })
    })

    it('switches the shape only with the dimensions of the new one', () => {
      // Z carries over, the diameter is still missing
      expect(updateInput(MK4, editing(MK4, { bedShape: 'circular' }))).toEqual({})
      expect(updateInput(MK4, editing(MK4, { bedShape: 'circular', diameter: 200 })))
        .toEqual({ specs: { buildVolume: { circular: { diameter: 200, height: 220 } } } })
      expect(updateInput(KOSSEL, editing(KOSSEL, { bedShape: 'rectangular', x: 100, y: 100 })))
        .toEqual({ specs: { buildVolume: { rectangular: { x: 100, y: 100, z: 300 } } } })
    })

    it('clears the build volume once all of its dimensions are cleared', () => {
      expect(updateInput(MK4, editing(MK4, { x: null, y: null, z: null }))).toEqual({ specs: { buildVolume: null } })
      expect(updateInput(KOSSEL, editing(KOSSEL, { diameter: null, z: null }))).toEqual({ specs: { buildVolume: null } })
    })

    it('tells a partial build volume apart', () => {
      expect(volumeInput({ bedShape: 'rectangular', x: 1, y: null, z: 3 })).toBeUndefined()
      expect(volumeInput({ bedShape: 'circular', diameter: '', z: undefined })).toBeNull()
    })
  })

  describe('firmwareOptions', () => {
    const values = (options) => options.map((option) => option.value)

    it('suggests the known firmwares', () => {
      expect(values(firmwareOptions(null))).toEqual(['marlin', 'klipper', 'prusa_firmware', 'reprapfirmware'])
      expect(firmwareOptions('klipper')).toHaveLength(4)
    })

    it('adds the saved text and what is typed, when new', () => {
      expect(values(firmwareOptions('Smoothie', 'Duet ')).slice(4)).toEqual(['Smoothie', 'Duet'])
      expect(firmwareOptions(null, 'prusa firmware')).toHaveLength(4)
      expect(firmwareOptions(null, 'Marlin')).toHaveLength(4)
    })
  })
})
