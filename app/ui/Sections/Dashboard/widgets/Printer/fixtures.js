// Printers in each state family, as the dashboard query returns them: for tests and the Add Widget gallery.
// Times are relative to FIXTURE_NOW.

export const FIXTURE_NOW = new Date('2026-11-14T13:23:00Z')

const celsius = (actual, target = 0) => ({ actual, target, unit: 'CELSIUS' })
const nextJob = (filename) => ({ id: filename, executable: { id: filename, filename } })
const camera = { enabled: true, streamUrl: 'http://printer.local/webcam/?action=stream' }

const status = (overrides) => ({
  stateFamily: 'OPERATIONAL',
  stateText: 'Operational',
  serverReachable: true,
  errorText: null,
  fileName: null,
  progress: null,
  printTimeLeft: null,
  hotend: null,
  bed: null,
  camera,
  lastSeenAt: FIXTURE_NOW.toISOString(),
  updatedAt: FIXTURE_NOW.toISOString(),
  ...overrides
})

const printer = (id, name, statusOverrides, extra = {}) => ({
  id,
  name,
  backend: 'OCTOPRINT',
  canStartNext: false,
  queuedCount: 0,
  nextJob: null,
  status: status(statusOverrides),
  ...extra
})

export const PRINTERS = {
  PRINTING: printer('1', 'Prusa MK4', {
    stateFamily: 'PRINTING', stateText: 'Printing', fileName: 'bracket_v3.gcode', progress: 64,
    printTimeLeft: 'PT1H12M', hotend: celsius(215, 215), bed: celsius(60, 60)
  }, { queuedCount: 3, nextJob: nextJob('cable_clip_x20.gcode') }),
  PAUSED: printer('2', 'Voron 2.4', {
    stateFamily: 'PAUSED', stateText: 'Paused', fileName: 'enclosure_panel.gcode', progress: 38,
    printTimeLeft: 'PT3H5M', hotend: celsius(175), bed: celsius(100, 100)
  }, { queuedCount: 1, nextJob: nextJob('calibration_cube.gcode') }),
  CANCELLING: printer('3', 'Ender 5 Plus, left workbench', {
    stateFamily: 'CANCELLING', stateText: 'Cancelling', fileName: 'vase_spiral.gcode', progress: 71,
    hotend: celsius(205), bed: celsius(55)
  }, { queuedCount: 1, nextJob: nextJob('lid_hinge_v4.gcode') }),
  OPERATIONAL: printer('4', 'Prusa Mini+', {
    hotend: celsius(24), bed: celsius(23)
  }, { canStartNext: true, queuedCount: 2, nextJob: nextJob('spool_holder.gcode') }),
  CONNECTING: printer('5', 'Voron Trident', { stateFamily: 'CONNECTING', stateText: 'Connecting' }),
  ERROR: printer('6', 'Ender 3 V2', {
    stateFamily: 'ERROR', stateText: 'Offline after error', fileName: 'gear_v2.gcode', progress: 12,
    camera: { enabled: false, streamUrl: null }
  }),
  // OctoPrint answers, but isn't connected to the printer
  OFFLINE: printer('7', 'Kobra 2', {
    stateFamily: 'OFFLINE', stateText: 'Offline', lastSeenAt: '2026-11-14T11:23:00Z'
  })
}

// OFFLINE because OctoPrint itself doesn't answer
export const UNREACHABLE = printer('8', 'Sidewinder X2', {
  stateFamily: 'OFFLINE', stateText: 'Unreachable', serverReachable: false, lastSeenAt: '2026-11-14T11:23:00Z',
  errorText: 'Failed to open TCP connection to octopi.local:80 (Connection refused)', hotend: null, bed: null
})

// A Printer widget's options with everything on
export const ALL_OPTIONS = { camera: true, timeLeft: true, temperatures: true, upNext: true, controls: true }
