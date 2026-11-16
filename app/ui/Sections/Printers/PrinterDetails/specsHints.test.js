import { describe, expect, it } from 'vitest'

import { formValues } from './detailsForm'
import { reloadedValues, reportedValues, specsHints } from './specsHints'

const MK4 = {
  name: 'Prusa MK4',
  backend: 'PRUSALINK',
  specs: {
    model: 'MK4',
    firmwareDisplayName: 'prusa_firmware',
    firmwareVersion: '6.2.0',
    nozzleDiameter: 0.6,
    buildVolume: { x: 250, y: 210, z: 220 },
    materials: []
  }
}
// What PrusaLink says about it
const PRUSALINK = { model: 'MK4', firmwareDisplayName: 'prusa_firmware', firmwareVersion: '6.2.1', nozzleDiameter: 0.4, materials: null }
const OCTOPRINT = {
  model: 'Kossel',
  buildVolume: { diameter: 230, height: 300 },
  extruders: 1,
  heatedBed: true,
  heatedChamber: false,
  webcam: false,
  materials: null
}

const hints = (printer, reported) => specsHints(printer.backend, formValues(printer), reported)

describe('specsHints', () => {
  it('shows nothing before the server answers', () => {
    expect(specsHints('PRUSALINK', formValues(MK4), null)).toEqual({})
    expect(specsHints('PRUSALINK', undefined, reportedValues(PRUSALINK))).toEqual({})
  })

  it('has no hint for what the server does not report', () => {
    const result = hints(MK4, reportedValues(null, null))
    expect(result).toEqual({})
    expect(hints(MK4, reportedValues(PRUSALINK, null))).not.toHaveProperty('name')
    expect(hints(MK4, reportedValues(PRUSALINK, null))).not.toHaveProperty('buildVolume')
  })

  it('says "From PrusaLink" when the form holds the reported value', () => {
    expect(hints(MK4, reportedValues(PRUSALINK, 'Prusa MK4'))).toMatchObject({
      name: 'From PrusaLink',
      model: 'From PrusaLink',
      firmware: 'From PrusaLink'
    })
  })

  it('tells the reported value, with its unit, when the form holds another', () => {
    expect(hints(MK4, reportedValues(PRUSALINK, 'MK4 #2'))).toMatchObject({
      name: 'PrusaLink reports MK4 #2',
      firmwareVersion: 'PrusaLink reports 6.2.1',
      nozzleDiameter: 'PrusaLink reports 0.4 mm'
    })
  })

  it("reads OctoPrint's profile: build volume, firmware names, switches", () => {
    const ender = { name: 'Ender', backend: 'OCTOPRINT', specs: { buildVolume: { x: 220, y: 220, z: 250 }, heatedBed: true, materials: [] } }
    expect(hints(ender, reportedValues({ ...OCTOPRINT, firmwareDisplayName: 'marlin' }))).toEqual({
      model: 'OctoPrint reports Kossel',
      firmware: 'OctoPrint reports Marlin',
      buildVolume: 'OctoPrint reports Ø 230 × 300 mm',
      extruders: 'OctoPrint reports 1',
      heatedBed: 'From OctoPrint',
      heatedChamber: 'OctoPrint reports off',
      webcam: 'OctoPrint reports off'
    })
    expect(hints({ ...ender, specs: { buildVolume: { diameter: 230, height: 300 } } }, reportedValues(OCTOPRINT)))
      .toMatchObject({ buildVolume: 'From OctoPrint' })
  })

  it('compares with what the form holds now', () => {
    const values = formValues(MK4)
    values.specs.nozzleDiameter = 0.4
    expect(specsHints('PRUSALINK', values, reportedValues(PRUSALINK)).nozzleDiameter).toBe('From PrusaLink')
  })

  describe('reloadedValues', () => {
    it('copies one reported value into the form', () => {
      const reported = reportedValues(PRUSALINK, 'MK4 #2')
      expect(reloadedValues('nozzleDiameter', reported)).toEqual({ specs: { nozzleDiameter: 0.4 } })
      expect(reloadedValues('firmware', reported)).toEqual({ specs: { firmware: 'prusa_firmware' } })
      expect(reloadedValues('name', reported)).toEqual({ name: 'MK4 #2' })
    })

    it('copies the whole build volume, its bed shape included', () => {
      expect(reloadedValues('buildVolume', reportedValues(OCTOPRINT)))
        .toEqual({ specs: { bedShape: 'circular', diameter: 230, z: 300 } })
      expect(reloadedValues('buildVolume', reportedValues({ buildVolume: { x: 1, y: 2, z: 3 } })))
        .toEqual({ specs: { bedShape: 'rectangular', x: 1, y: 2, z: 3 } })
    })
  })
})
