import { describe, expect, it } from 'vitest'

import fleetView, { filterFleet, formatBuildVolume, matchesSearch, needsAttention, sortFleet } from './fleetView'
import { FIXTURE_NOW, PRINTERS, UNREACHABLE } from '../../Dashboard/widgets/Printer/fixtures'

const rectangular = { x: 250, y: 210, z: 220 }
const fleetPrinter = (printer, { favorite = false, brand = null, model = null, buildVolume = null, ...extra } = {}) => ({
  ...printer, uri: 'http://192.168.1.21', favorite, specs: { brand, model, buildVolume }, ...extra
})
// The printers of each state family, plus UNREACHABLE: OFFLINE because OctoPrint doesn't answer
const FIXTURES = { ...PRINTERS, UNREACHABLE }
const view = (family, options) => fleetView(fleetPrinter(FIXTURES[family], options), FIXTURE_NOW.getTime())
const ids = (printers) => printers.map((printer) => printer.id)

describe('fleetView', () => {
  it('sorts favorites first, then by id', () => {
    const printers = [
      fleetPrinter(PRINTERS.OFFLINE), fleetPrinter(PRINTERS.ERROR, { favorite: true }), fleetPrinter(PRINTERS.PRINTING),
      fleetPrinter(PRINTERS.PAUSED, { favorite: true })
    ]
    expect(ids(sortFleet(printers))).toEqual(['2', '6', '1', '7'])
  })

  it.each([
    ['ERROR', true], ['OFFLINE', true], ['CANCELLING', true],
    ['CONNECTING', false], ['PRINTING', false], ['PAUSED', false], ['OPERATIONAL', false]
  ])('says whether a %s printer needs attention: %s', (family, expected) => {
    expect(needsAttention(PRINTERS[family])).toBe(expected)
  })

  it('searches the name, brand and model, whatever the case', () => {
    const printer = fleetPrinter(PRINTERS.PRINTING, { brand: 'Prusa Research', model: 'MK4S' })
    expect(['mk4', 'RESEARCH', 'mk4s', '  ', ''].map((search) => matchesSearch(printer, search)))
      .toEqual([true, true, true, true, true])
    expect(matchesSearch(printer, 'voron')).toBe(false)
    expect(matchesSearch(fleetPrinter(PRINTERS.OFFLINE), 'kobra')).toBe(true)
  })

  it('filters favorites or printers needing attention, with the search, sorted', () => {
    const printers = [
      fleetPrinter(PRINTERS.OFFLINE, { favorite: true }), fleetPrinter(PRINTERS.ERROR),
      fleetPrinter(PRINTERS.PRINTING, { favorite: true }), fleetPrinter(PRINTERS.CONNECTING)
    ]
    expect(ids(filterFleet(printers))).toEqual(['1', '7', '5', '6'])
    expect(ids(filterFleet(printers, { filter: 'Favorites' }))).toEqual(['1', '7'])
    expect(ids(filterFleet(printers, { filter: 'Needs Attention' }))).toEqual(['7', '6'])
    expect(ids(filterFleet(printers, { filter: 'Needs Attention', search: 'ender' }))).toEqual(['6'])
  })

  it('shows the brand and model, or nothing so the row links to add them, then the server', () => {
    expect(view('PRINTING', { brand: 'Prusa Research', model: 'MK4' })).toMatchObject({ brandModel: 'Prusa Research MK4', product: 'OctoPrint' })
    expect(view('PRINTING', { model: 'MK4' }).brandModel).toBe('MK4')
    expect(fleetView({ ...fleetPrinter(PRINTERS.OFFLINE), backend: 'PRUSALINK' }, FIXTURE_NOW.getTime()))
      .toMatchObject({ brandModel: null, product: 'PrusaLink' })
  })

  it.each([
    ['PRINTING', { fileName: 'bracket_v3.gcode', progress: 64, timeLeft: 72 * 60 * 1000 }],
    ['PAUSED', { fileName: 'enclosure_panel.gcode', progress: 38, timeLeft: null }],
    ['CANCELLING', { fileName: 'vase_spiral.gcode', progress: 71, timeLeft: null }]
  ])('shows the file and progress of a %s printer', (family, job) => {
    expect(view(family)).toMatchObject({ job, now: null })
  })

  it('says an idle printer is ready', () => {
    expect(view('OPERATIONAL')).toMatchObject({ job: null, now: { text: 'Idle, ready for the next job', muted: true } })
  })

  it('says an offline printer is unreachable, with its server and when it was last seen', () => {
    expect(view('UNREACHABLE').now).toEqual({ text: 'OctoPrint unreachable. Last seen 2 h ago', muted: true })
    const prusa = { ...PRINTERS.OFFLINE, backend: 'PRUSALINK', status: { ...PRINTERS.OFFLINE.status, lastSeenAt: null } }
    expect(fleetView(fleetPrinter(prusa), FIXTURE_NOW.getTime()).now.text).toBe('PrusaLink unreachable.')
  })

  it('says OctoPrint is up when only its printer is offline', () => {
    expect(view('OFFLINE').now).toEqual({ text: "OctoPrint is running, but the printer isn't connected", muted: true })
  })

  it("shows an error printer's error, else its state text", () => {
    expect(view('ERROR').now).toEqual({ text: 'Offline after error', muted: false })
    const error = { ...PRINTERS.ERROR, status: { ...PRINTERS.ERROR.status, errorText: 'Heating failed' } }
    expect(fleetView(fleetPrinter(error), FIXTURE_NOW.getTime()).now.text).toBe('Heating failed')
  })

  it('formats a rectangular or circular build volume, or says it is not set', () => {
    expect(formatBuildVolume(rectangular)).toBe('250 × 210 × 220 mm')
    expect(formatBuildVolume({ x: 180.5, y: 180, z: 180 })).toBe('180.5 × 180 × 180 mm')
    expect(formatBuildVolume({ diameter: 180, height: 300 })).toBe('Ø 180 × 300 mm')
    expect(view('PRINTING', { buildVolume: rectangular }).buildVolume).toBe('250 × 210 × 220 mm')
    expect(view('PRINTING').buildVolume).toBeNull()
  })

  it('links to the queue when it has jobs', () => {
    expect(view('PRINTING').queue).toEqual({ text: '3 in queue', to: '/printers/1/queue' })
    expect(view('OFFLINE').queue).toBeNull()
  })

  it.each([
    ['OFFLINE', 'OCTOPRINT', 'Connect', null],
    ['UNREACHABLE', 'OCTOPRINT', 'Edit Connection', '/printers/8'],
    ['OFFLINE', 'PRUSALINK', 'Edit Connection', '/printers/7'],
    ['ERROR', 'OCTOPRINT', 'Reconnect', null],
    ['ERROR', 'PRUSALINK', 'Edit Connection', '/printers/6'],
    ['PRINTING', 'OCTOPRINT', 'Open Queue', '/printers/1/queue'],
    ['CONNECTING', 'OCTOPRINT', 'Open Queue', '/printers/5/queue']
  ])('offers the main action of a %s %s printer: %s', (family, backend, label, to) => {
    const printer = fleetPrinter({ ...FIXTURES[family], backend })
    const { mainAction } = fleetView(printer, FIXTURE_NOW.getTime())
    expect([mainAction.label, mainAction.to ?? null]).toEqual([label, to])
  })

  it.each([
    ['PRINTING', true], ['PAUSED', true], ['CANCELLING', true], ['OPERATIONAL', true], ['CONNECTING', true],
    ['OFFLINE', false], ['UNREACHABLE', false], ['ERROR', false]
  ])('tints the avatar of a %s printer: %s', (family, tinted) => {
    expect(view(family).tinted).toBe(tinted)
  })

  it.each([
    ['PRINTING', 'OCTOPRINT', ['details', 'openServer', 'pause', 'cancel', 'reconnect', 'remove']],
    ['PAUSED', 'PRUSALINK', ['details', 'openServer', 'resume', 'cancel', 'remove']],
    ['OPERATIONAL', 'PRUSALINK', ['details', 'openServer', 'startNext', 'remove']],
    ['CANCELLING', 'PRUSALINK', ['details', 'openServer', 'remove']],
    ['OFFLINE', 'OCTOPRINT', ['details', 'openServer', 'reconnect', 'remove']]
  ])('lists the menu of a %s %s printer', (family, backend, menu) => {
    expect(fleetView(fleetPrinter({ ...PRINTERS[family], backend }), FIXTURE_NOW.getTime()).menu).toEqual(menu)
  })

  it('leaves Start Next out when nothing can start, and Open out without an address', () => {
    expect(view('OPERATIONAL', { canStartNext: false, uri: null }).menu).toEqual(['details', 'reconnect', 'remove'])
  })
})
