import { describe, expect, it } from 'vitest'
import printerView, { formatTemperature } from './printerView'
import { ALL_OPTIONS, FIXTURE_NOW, PRINTERS } from './fixtures'

const view = (family, { size = 'L', options = {}, printer = {} } = {}) => printerView({
  printer: { ...PRINTERS[family], ...printer },
  size,
  options: { ...ALL_OPTIONS, ...options },
  now: FIXTURE_NOW
})

describe('printerView', () => {
  describe('by state family', () => {
    it.each([
      ['PRINTING', 'bracket_v3.gcode', /^1 h 12 min left · done at \d\d:\d\d$/, ['pause', 'cancel']],
      ['PAUSED', 'enclosure_panel.gcode', 'Paused at 38%', ['resume', 'cancel']],
      ['CANCELLING', 'vase_spiral.gcode', 'Stopping at 71%', ['cancelling']],
      ['OPERATIONAL', 'Ready to print', 'Up next: spool_holder.gcode', ['startNext']],
      ['CONNECTING', 'Connecting to OctoPrint', 'This can take a few seconds', []],
      ['ERROR', 'Stopped responding', 'Stopped gear_v2.gcode at 12%', ['reconnect']],
      ['OFFLINE', 'Offline', 'Last seen 2 h ago', ['connect']]
    ])('%s reads "%s", with its controls', (family, headline, subline, actions) => {
      const result = view(family)
      expect(result.headline).toBe(headline)
      expect(result.subline).toEqual(subline instanceof RegExp ? expect.stringMatching(subline) : subline)
      expect(result.actions.map((action) => action.key)).toEqual(actions)
    })

    it('shows a ring while a job is under way, a spinner while connecting and the state icon otherwise', () => {
      expect(['PRINTING', 'PAUSED', 'CANCELLING'].map((family) => view(family).ring)).toEqual([true, true, true])
      expect(view('CONNECTING')).toMatchObject({ ring: false, spin: true, icon: false })
      expect(['OPERATIONAL', 'ERROR', 'OFFLINE'].map((family) => view(family).icon)).toEqual([true, true, true])
    })

    it('colours the tile by state family', () => {
      expect(view('PRINTING')).toMatchObject({ color: '#722ed1', tint: '#f9f0ff' })
      expect(view('ERROR')).toMatchObject({ color: '#ff4d4f', tint: '#fff2f0' })
    })

    it('offers Start Next only when the printer can start its next job', () => {
      expect(view('OPERATIONAL', { printer: { canStartNext: false } }).actions).toEqual([])
    })

    it('says the queue is empty when a ready printer has nothing next', () => {
      expect(view('OPERATIONAL', { printer: { nextJob: null } }).subline).toBe('Queue is empty')
    })

    it('hides temperatures when the printer is unreachable', () => {
      expect(view('ERROR', { printer: { status: { ...PRINTERS.ERROR.status, hotend: PRINTERS.PRINTING.status.hotend } } }).temps).toEqual([])
    })

    it('counts the time left down from the snapshot, with the dashboard clock', () => {
      const later = printerView({
        printer: PRINTERS.PRINTING, size: 'L', options: ALL_OPTIONS, now: new Date(FIXTURE_NOW.getTime() + 30 * 60 * 1000)
      })
      expect(later.timeText).toBe('42 min left')
    })

    it('shows the progress instead of the time when Time left is off', () => {
      expect(view('PRINTING', { options: { timeLeft: false } })).toMatchObject({ showTime: false, subline: '64% printed' })
    })
  })

  describe('options per size', () => {
    it('never shows the camera at Small', () => {
      expect(view('PRINTING', { size: 'S' }).camera).toBe(false)
      expect(view('PRINTING', { size: 'M' }).camera).toBe(true)
    })

    it('shows the controls at Large and Extra Large only', () => {
      expect(['S', 'M', 'L', 'XL'].map((size) => view('PRINTING', { size }).showActions)).toEqual([false, false, true, true])
      expect(view('PRINTING', { options: { controls: false } }).showActions).toBe(false)
    })

    it('shows up next at Extra Large, and at Large when the camera is off', () => {
      expect(view('PRINTING', { size: 'L' }).showNext).toBe(false)
      expect(view('PRINTING', { size: 'L', options: { camera: false } }).showNext).toBe(true)
      expect(view('PRINTING', { size: 'XL' })).toMatchObject({ showNext: true, nextText: 'Up next: cable_clip_x20.gcode' })
      expect(view('PRINTING', { size: 'M', options: { camera: false } }).showNext).toBe(false)
    })

    it('puts the temperatures on the meta line at Medium and beside a camera', () => {
      expect(view('PRINTING', { size: 'M' }).metaLine).toMatch(/ · Hotend 215° \/ 215° · Bed 60° \/ 60°$/)
      expect(view('PRINTING', { size: 'L' })).toMatchObject({ showTemps: false, metaLine: expect.stringMatching(/Hotend/) })
      expect(view('PRINTING', { size: 'L', options: { camera: false } }).showTemps).toBe(true)
      expect(view('PRINTING', { size: 'S' }).showTemps).toBe(false)
    })
  })

  describe('camera', () => {
    it('streams a reachable printer', () => {
      expect(view('PRINTING')).toMatchObject({ cameraLive: true, cameraOff: false })
    })

    it('says why there is no stream', () => {
      expect(view('ERROR').cameraMessage).toEqual({ message: 'No camera', hint: 'Add a webcam in OctoPrint' })
      expect(view('OFFLINE').cameraMessage).toEqual({ message: 'Camera offline', hint: 'Kobra 2 is offline' })
      expect(view('CONNECTING').cameraMessage).toEqual({ message: 'Camera offline', hint: 'Waiting for the printer' })
      expect(view('OFFLINE')).toMatchObject({ cameraLive: false, cameraOff: true })
    })

    it('only points OctoPrint printers to OctoPrint for a webcam', () => {
      expect(view('ERROR', { printer: { backend: 'PRUSALINK' } }).cameraMessage).toEqual({ message: 'No camera', hint: '' })
    })
  })

  describe('PrusaLink printers', () => {
    const prusalink = (family) => view(family, { printer: { backend: 'PRUSALINK' } })

    it('offer no Connect or Reconnect: PrusaLink connects on its own', () => {
      expect(prusalink('OFFLINE').actions).toEqual([])
      expect(prusalink('ERROR').actions).toEqual([])
      expect(prusalink('PRINTING').actions.map((action) => action.key)).toEqual(['pause', 'cancel'])
    })

    it('do not ask to reconnect after an error', () => {
      const error = { ...PRINTERS.ERROR.status, fileName: null }
      expect(view('ERROR', { printer: { backend: 'PRUSALINK', status: error } }).subline).toBe('Check the printer')
      expect(view('ERROR', { printer: { status: error } }).subline).toBe('Check the printer and reconnect')
    })
  })

  it('formats temperatures with their unit', () => {
    expect(formatTemperature({ actual: 214.6, target: 215, unit: 'CELSIUS' })).toBe('215° / 215°')
    expect(formatTemperature({ actual: 24, target: 0, unit: 'CELSIUS' })).toBe('24°')
    expect(formatTemperature({ actual: 419, target: 419, unit: 'FAHRENHEIT' })).toBe('419°F / 419°F')
    expect(formatTemperature({ actual: 488, target: 0, unit: 'KELVIN' })).toBe('488 K')
  })
})
