import { statePalette } from '../../../../Foundation/theme'
import { doneAt, formatAgo, formatClock, formatTimeLeft } from '../../../../utils/time'

const IN_PROGRESS = ['PRINTING', 'PAUSED', 'CANCELLING']
const UNREACHABLE = ['OFFLINE', 'CONNECTING', 'ERROR']
const UNIT_SYMBOLS = { CELSIUS: '°', FAHRENHEIT: '°F', KELVIN: ' K' }

// Ring, state icon and spinner sizes, per widget size
const RING_SIZE = { S: 64, M: 104, L: 96, XL: 168 }
const ICON_CIRCLE = { S: 64, M: 88, L: 84, XL: 120 }
const ICON_FONT = { S: 28, M: 36, L: 34, XL: 48 }

// "215° / 215°", or "24°" when the heater is off
export function formatTemperature ({ actual, target, unit }) {
  const symbol = UNIT_SYMBOLS[unit] ?? '°'
  const value = (degrees) => `${Math.round(degrees)}${symbol}`
  return target ? `${value(actual)} / ${value(target)}` : value(actual)
}

// The controls of each state family, before options and confirmations. Connect and Reconnect are OctoPrint's:
// PrusaLink connects to its printer on its own.
function actionsFor (family, canStartNext, octoprint) {
  switch (family) {
    case 'PRINTING': return [{ key: 'pause', label: 'Pause' }, { key: 'cancel', label: 'Cancel', danger: true }]
    case 'PAUSED': return [{ key: 'resume', label: 'Resume' }, { key: 'cancel', label: 'Cancel', danger: true }]
    case 'CANCELLING': return [{ key: 'cancelling', label: 'Cancelling', loading: true, disabled: true }]
    case 'OPERATIONAL': return canStartNext ? [{ key: 'startNext', label: 'Start Next' }] : []
    case 'ERROR': return octoprint ? [{ key: 'reconnect', label: 'Reconnect' }] : []
    case 'OFFLINE': return octoprint ? [{ key: 'connect', label: 'Connect' }] : []
    default: return []
  }
}

// Only OctoPrint has webcam settings to point to
function cameraMessage (family, name, camera, octoprint) {
  if (!camera.enabled) return { message: 'No camera', hint: octoprint ? 'Add a webcam in OctoPrint' : '' }
  if (family === 'CONNECTING') return { message: 'Camera offline', hint: 'Waiting for the printer' }
  if (family === 'ERROR') return { message: 'Camera offline', hint: `${name} stopped responding` }
  if (family === 'OFFLINE') return { message: 'Camera offline', hint: `${name} is offline` }
  return { message: 'Camera offline', hint: '' }
}

// Everything a Printer widget shows, for its size ('S', 'M', 'L' or 'XL'), options and state, at `now`.
// `streamFailed` is set once the camera stream failed to load.
export default function printerView ({ printer, size, options, now, streamFailed = false }) {
  const { name, status, canStartNext, nextJob } = printer
  const octoprint = printer.backend === 'OCTOPRINT'
  const family = status.stateFamily
  const palette = statePalette(family)
  const hasJob = IN_PROGRESS.includes(family)
  const reachable = !UNREACHABLE.includes(family)
  const progress = status.progress ?? 0
  const next = nextJob?.executable?.filename

  const temps = reachable
    ? [['Hotend', status.hotend], ['Bed', status.bed]]
        .filter(([, temperature]) => temperature)
        .map(([label, temperature]) => ({ label, value: formatTemperature(temperature) }))
    : []
  const tempsLine = temps.map((temp) => `${temp.label} ${temp.value}`).join(' · ')

  const finish = family === 'PRINTING' ? doneAt(status.updatedAt, status.printTimeLeft) : null
  const timeText = finish ? `${formatTimeLeft(finish.diff(now))} left` : ''
  const showTime = !!(options.timeLeft && timeText)

  let headline
  if (hasJob) headline = status.fileName || 'Unnamed job'
  else if (family === 'OPERATIONAL') headline = 'Ready to print'
  else if (family === 'CONNECTING') headline = 'Connecting to OctoPrint'
  else if (family === 'ERROR') headline = 'Stopped responding'
  else headline = 'Offline'

  let subline
  if (family === 'PRINTING') subline = showTime ? `${timeText} · done at ${formatClock(finish)}` : `${progress}% printed`
  else if (family === 'PAUSED') subline = `Paused at ${progress}%`
  else if (family === 'CANCELLING') subline = `Stopping at ${progress}%`
  else if (family === 'OPERATIONAL') subline = next ? `Up next: ${next}` : 'Queue is empty'
  else if (family === 'CONNECTING') subline = 'This can take a few seconds'
  else if (family === 'ERROR') {
    const check = octoprint ? 'Check the printer and reconnect' : 'Check the printer'
    subline = status.fileName ? `Stopped ${status.fileName} at ${progress}%` : check
  } else subline = status.lastSeenAt ? `Last seen ${formatAgo(status.lastSeenAt, now)}` : 'Not connected'

  const actions = actionsFor(family, canStartNext, octoprint)
  const big = size === 'L' || size === 'XL'

  const camera = !!(options.camera && size !== 'S')
  const cameraLive = camera && status.camera.enabled && !!status.camera.streamUrl && reachable && !streamFailed
  const showTempsInline = options.temperatures && temps.length > 0 && (size === 'M' || camera)

  return {
    name,
    family,
    stateText: status.stateText,
    color: palette.color,
    tint: palette.tint,
    progress,
    ring: hasJob,
    spin: family === 'CONNECTING',
    icon: !hasJob && family !== 'CONNECTING',
    ringSize: RING_SIZE[size],
    iconCircle: ICON_CIRCLE[size],
    iconFont: ICON_FONT[size],
    headline,
    subline,
    showTime,
    timeText,
    temps,
    tempsLine,
    showTemps: !!(options.temperatures && temps.length > 0 && size !== 'S' && !(size === 'L' && camera)),
    metaLine: showTempsInline ? `${subline} · ${tempsLine}` : subline,
    showNext: !!(options.upNext && next && family !== 'OPERATIONAL' && (size === 'XL' || (size === 'L' && !camera))),
    nextText: `Up next: ${next}`,
    nextJobName: next,
    actions,
    showActions: !!(options.controls && big && actions.length > 0),
    camera,
    cameraLive,
    cameraOff: camera && !cameraLive,
    cameraMessage: cameraMessage(family, name, status.camera, octoprint),
    streamUrl: status.camera.streamUrl,
    progressBar: hasJob && camera
  }
}
