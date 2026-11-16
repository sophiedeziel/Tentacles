import { NEEDS_ATTENTION_FAMILIES } from '../../../Foundation/theme'
import { doneAt, formatAgo } from '../../../utils/time'
import { canConnect } from '../../Dashboard/widgets/Printer/printerView'

export const FILTERS = ['All', 'Favorites', 'Needs Attention']

export const PRODUCTS = { OCTOPRINT: 'OctoPrint', PRUSALINK: 'PrusaLink' }
const WITH_JOB = ['PRINTING', 'PAUSED', 'CANCELLING']

// "OctoPrint" or "PrusaLink": the server Tentacles talks to
export const productName = (backend) => PRODUCTS[backend] || backend

export const needsAttention = (printer) => NEEDS_ATTENTION_FAMILIES.includes(printer.status?.stateFamily || 'OFFLINE')

// Favorites first, then in the order they were added
export function sortFleet (printers) {
  return [...printers].sort((a, b) => (b.favorite - a.favorite) || (Number(a.id) - Number(b.id)))
}

// The name, brand or model contains the search, whatever the case
export function matchesSearch (printer, search) {
  const query = search.trim().toLowerCase()
  if (!query) return true
  return [printer.name, printer.specs?.brand, printer.specs?.model]
    .some((text) => text?.toLowerCase().includes(query))
}

// The rows to show for a filter (one of FILTERS) and a search, sorted
export function filterFleet (printers, { filter = 'All', search = '' } = {}) {
  return sortFleet(printers).filter((printer) => (
    (filter !== 'Favorites' || printer.favorite) &&
    (filter !== 'Needs Attention' || needsAttention(printer)) &&
    matchesSearch(printer, search)
  ))
}

// "250 × 210 × 220 mm", "Ø 180 × 300 mm" for a circular bed, null when not set
export function formatBuildVolume (volume) {
  if (!volume) return null
  const mm = (value) => Number(value).toLocaleString('en-US', { maximumFractionDigits: 1 })
  if (volume.diameter != null) return `Ø ${mm(volume.diameter)} × ${mm(volume.height)} mm`
  return `${mm(volume.x)} × ${mm(volume.y)} × ${mm(volume.z)} mm`
}

// What the Now column says when no job is under way. OFFLINE is either a server that doesn't answer or, when it
// can connect, OctoPrint answering without its printer.
function nowText (family, status, product, now, connectable) {
  if (family === 'OPERATIONAL') return { text: 'Idle, ready for the next job', muted: true }
  if (family === 'ERROR') return { text: status.errorText || status.stateText, muted: false }
  if (family === 'CONNECTING') return { text: `Connecting to ${product}`, muted: true }
  if (connectable) return { text: `${product} is running, but the printer isn't connected`, muted: true }
  const seen = status.lastSeenAt ? ` Last seen ${formatAgo(status.lastSeenAt, now)}` : ''
  return { text: `${product} unreachable.${seen}`, muted: true }
}

// The button beside the ⋯ menu: connect a printer OctoPrint isn't connected to, fix the connection of a printer
// that can't be reached, else open its queue
function mainAction (family, octoprint, id, connectable) {
  if (connectable) return { key: 'connect', label: 'Connect' }
  if (family === 'ERROR' && octoprint) return { key: 'reconnect', label: 'Reconnect' }
  if (family === 'OFFLINE' || family === 'ERROR') return { key: 'editConnection', label: 'Edit Connection', to: `/printers/${id}` }
  return { key: 'openQueue', label: 'Open Queue', to: `/printers/${id}/queue` }
}

// The job controls of the ⋯ menu for a state (the dashboard's mutations and confirmations)
function jobControls (family, canStartNext) {
  if (family === 'PRINTING') return ['pause', 'cancel']
  if (family === 'PAUSED') return ['resume', 'cancel']
  if (family === 'OPERATIONAL' && canStartNext) return ['startNext']
  return []
}

// The ⋯ menu, top to bottom. Reconnect is OctoPrint's: PrusaLink connects to its printer on its own.
export function menuKeys (printer) {
  return [
    'details',
    ...(printer.uri ? ['openServer'] : []),
    ...jobControls(printer.status?.stateFamily || 'OFFLINE', printer.canStartNext),
    ...(printer.backend === 'OCTOPRINT' ? ['reconnect'] : []),
    'remove'
  ]
}

// Everything a row of the fleet list shows for a printer, at `now`
export default function fleetView (printer, now) {
  const status = printer.status || { stateFamily: 'OFFLINE', stateText: 'Offline' }
  const family = status.stateFamily
  const octoprint = printer.backend === 'OCTOPRINT'
  const product = productName(printer.backend)
  const brandModel = [printer.specs?.brand, printer.specs?.model].filter(Boolean).join(' ')
  const finish = family === 'PRINTING' ? doneAt(status.updatedAt, status.printTimeLeft) : null
  const connectable = canConnect(printer)

  return {
    family,
    stateText: status.stateText,
    product,
    // Brand and model, or a link to add them, then the server: "Prusa Research MK4 · PrusaLink"
    brandModel: brandModel || null,
    job: WITH_JOB.includes(family)
      ? { fileName: status.fileName || 'Unnamed job', progress: status.progress ?? 0, timeLeft: finish ? finish.diff(now) : null }
      : null,
    now: WITH_JOB.includes(family) ? null : nowText(family, status, product, now, connectable),
    buildVolume: formatBuildVolume(printer.specs?.buildVolume),
    queue: printer.queuedCount > 0 ? { text: `${printer.queuedCount} in queue`, to: `/printers/${printer.id}/queue` } : null,
    mainAction: mainAction(family, octoprint, printer.id, connectable),
    // The avatar is tinted purple unless the printer can't be reached
    tinted: family !== 'OFFLINE' && family !== 'ERROR',
    menu: menuKeys(printer)
  }
}
