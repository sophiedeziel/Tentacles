import { statePalette } from '../../../../Foundation/theme'
import { doneAt, formatAgo, formatTimeLeft } from '../../../../utils/time'

const IN_PROGRESS = ['PRINTING', 'PAUSED', 'CANCELLING']
const BIG = ['XL', 'XXL']

// What a printer is doing, for the per-printer table: its sort rank, and its name in the "+ N more printers" line.
// Ready with work waiting comes first, then printing, paused, error, and idle and offline last.
const BUCKETS = [
  { key: 'ready', rank: 0, label: 'ready' },
  { key: 'printing', rank: 1, label: 'printing' },
  { key: 'paused', rank: 2, label: 'paused' },
  { key: 'cancelling', rank: 2, label: 'cancelling' },
  { key: 'error', rank: 3, label: 'in error' },
  { key: 'connecting', rank: 4, label: 'connecting' },
  { key: 'idle', rank: 5, label: 'idle' },
  { key: 'offline', rank: 6, label: 'offline' }
]
const RANK = Object.fromEntries(BUCKETS.map((bucket) => [bucket.key, bucket.rank]))

// What the "Now" column says when nothing is printing
const IDLE_TEXT = { ready: 'Idle', idle: 'Idle', error: 'Stopped responding', connecting: 'Connecting', offline: 'Offline' }

// The per-printer table's rows: XL folds past 6 printers, XXL past 10
export const TABLE_ROWS = { XL: 6, XXL: 10 }

// The most up next rows each size fits, and its history rows (XXL with one row per printer has 5 of each, under
// the table)
const MAX_NEXT = { M: 3, L: 8, XL: 8, XXL: 15 }
const MAX_HISTORY = { XL: 7, XXL: 16 }
const UNDER_TABLE = 5

// The height (px) a size leaves for the up next column, under the widget's header
const COLUMN_HEIGHT = { L: 304, XL: 296, XXL: 656 }
const ROW = 32
const LABEL = 26
const READY_BAR = 42

export function bucketOf (printer) {
  switch (printer.status.stateFamily) {
    case 'OPERATIONAL': return printer.queuedCount > 0 ? 'ready' : 'idle'
    case 'PRINTING': return 'printing'
    case 'PAUSED': return 'paused'
    case 'CANCELLING': return 'cancelling'
    case 'ERROR': return 'error'
    case 'CONNECTING': return 'connecting'
    default: return 'offline'
  }
}

// The printers in the table's order: by bucket, then by name
export function sortPrinters (printers) {
  return [...printers].sort((a, b) => RANK[bucketOf(a)] - RANK[bucketOf(b)] || a.name.localeCompare(b.name))
}

// The rows that fit `max`: all of them, or max - 1 and a "+ N more printers: 1 paused · 2 idle" line counting the
// rest by state (always 2 or more: a single row takes the line's place)
export function foldRows (rows, max) {
  if (rows.length <= max) return { shown: rows, moreText: null }

  const shown = rows.slice(0, max - 1)
  const hidden = rows.slice(max - 1)
  const counts = BUCKETS
    .map((bucket) => [bucket.label, hidden.filter((row) => row.bucket === bucket.key).length])
    .filter(([, count]) => count > 0)
    .map(([label, count]) => `${count} ${label}`)
  return { shown, moreText: `+ ${hidden.length} more printers: ${counts.join(' · ')}` }
}

// Whether the widget shows one row per printer: all printers at XL and XXL, with the option on
export function isTableMode (size, options, single) {
  return BIG.includes(size) && !single && !!options.rowPerPrinter
}

// How many queue and history rows a widget shows at most, so it loads no more: 0 skips the query
export function rowsToLoad (size, options, single) {
  if (size === 'S') return { queue: 0, history: 0 }
  if (isTableMode(size, options, single)) {
    return size === 'XXL' ? { queue: UNDER_TABLE, history: options.history ? UNDER_TABLE : 0 } : { queue: 0, history: 0 }
  }
  return { queue: MAX_NEXT[size], history: options.history && MAX_HISTORY[size] ? MAX_HISTORY[size] : 0 }
}

// How many up next rows fit in a column of `height` px, under the printing jobs and above the ready bar. Room for
// a "+ N more" line is kept when the queue doesn't fit.
export function fitNextRows (height, { nowCount, single, ready, total, max }) {
  let available = height - LABEL
  if (nowCount > 0) available -= LABEL + nowCount * ((single ? 58 : 40) + 6)
  if (ready) available -= READY_BAR
  let rows = Math.floor(available / ROW)
  if (total > rows) rows = Math.floor((available - LABEL) / ROW)
  return Math.min(max, Math.max(1, rows))
}

// A printing (or paused, or cancelling) job, from the printer's live status
function nowItem (printer, single, now) {
  const { status } = printer
  const family = status.stateFamily
  const palette = statePalette(family)
  const progress = status.progress ?? 0
  const finish = family === 'PRINTING' ? doneAt(status.updatedAt, status.printTimeLeft) : null
  const timeLeft = finish ? formatTimeLeft(finish.diff(now)) : null

  let meta
  if (family === 'PRINTING') meta = timeLeft ? `${timeLeft} left` : `${progress}% printed`
  else if (family === 'PAUSED') meta = `Paused at ${progress}%`
  else meta = `Stopping at ${progress}%`

  return {
    printerId: printer.id,
    name: printer.name,
    file: status.fileName || 'Unnamed job',
    progress,
    color: palette.color,
    tint: palette.tint,
    meta,
    // All printers: the meta joins the printer's name. One printer: it gets its own line.
    printer: single ? '' : `${printer.name} · ${meta}`,
    showMeta: single,
    // The table's "Now" column
    short: family === 'PRINTING' ? (timeLeft || `${progress}%`) : `${progress}%`
  }
}

// Everything a Print Queue widget shows, for its size, options and scope, at `now`:
// - printers: the dashboard's printers ({ id name status canStartNext queuedCount nextJob })
// - printerId: the printer it follows, or null for all printers
// - queue: { totalCount, jobs } from printQueue, null until loaded; history: jobHistory's jobs, null until loaded
export default function queueView ({ printers, printerId = null, size, options, queue = null, history = null, now }) {
  const single = !!printerId
  const scoped = sortPrinters(single ? printers.filter((printer) => printer.id === printerId) : printers)
  const nameOf = (job) => printers.find((printer) => printer.id === job.printer?.id)?.name || job.printer?.name || ''

  const nowItems = scoped.filter((printer) => IN_PROGRESS.includes(printer.status.stateFamily))
    .map((printer) => nowItem(printer, single, now))
  const count = queue ? queue.totalCount : scoped.reduce((total, printer) => total + printer.queuedCount, 0)
  const next = (queue?.jobs || []).map((job, index) => ({
    id: job.id, pos: index + 1, file: job.executable?.filename || 'Unnamed job', printer: single ? '' : nameOf(job)
  }))
  const empty = nowItems.length === 0 && count === 0
  const showNow = !!(options.nowPrinting && nowItems.length > 0)
  const moreText = (shown) => (queue && count > shown ? `+ ${count - shown} more` : null)

  // The Start Next bar: the first printer that can start its next job, in the table's order
  const readyPrinter = scoped.find((printer) => printer.canStartNext && printer.nextJob)
  const table = isTableMode(size, options, single) && !empty
  const ready = readyPrinter && {
    printer: readyPrinter,
    label: `${readyPrinter.name} is ready for ${readyPrinter.nextJob.executable.filename}`
  }
  const showReady = !!(options.startNext && ready && ['L', 'XL', 'XXL'].includes(size) && !table)

  const view = {
    single,
    title: single ? `${scoped[0]?.name || 'Print'} queue` : 'Print Queue',
    smallTitle: single ? scoped[0]?.name || 'Print Queue' : 'Print Queue',
    count,
    countLabel: count === 1 ? 'job queued' : 'jobs queued',
    queuedLabel: count === 0 ? 'Nothing queued' : `${count} queued`,
    empty,
    ready: showReady ? ready : null
  }

  if (size === 'M') {
    // What prints now (its time left for one printer, its printer for all), then the next jobs
    const nowRows = showNow ? [{ ...nowItems[0], isNow: true, side: single ? nowItems[0].meta : nowItems[0].name }] : []
    return { ...view, rows: [...nowRows, ...next].slice(0, MAX_NEXT.M) }
  }

  if (size === 'L' || (BIG.includes(size) && !table)) {
    const nowShown = showNow ? nowItems.slice(0, single ? 1 : 2) : []
    const fit = fitNextRows(COLUMN_HEIGHT[size], {
      nowCount: nowShown.length, single, ready: showReady, total: count, max: MAX_NEXT[size]
    })
    const nextShown = next.slice(0, fit)
    const historyRows = (history || []).slice(0, MAX_HISTORY[size]).map((job) => historyItem(job, single, nameOf, now))
    return {
      ...view,
      now: nowShown,
      next: nextShown,
      moreText: moreText(nextShown.length),
      showHistory: !!(options.history && BIG.includes(size)),
      history: historyRows,
      // One printer with history keeps its columns when its queue is empty, so a failed job stays visible
      list: BIG.includes(size) && (!empty || (single && !!options.history && historyRows.length > 0))
    }
  }

  if (table) {
    const rows = scoped.map((printer) => tableRow(printer, single, now, options))
    return {
      ...view,
      table: true,
      ...foldRows(rows, TABLE_ROWS[size]),
      under: size === 'XXL' && {
        next: next.slice(0, UNDER_TABLE),
        showHistory: !!options.history,
        history: (history || []).slice(0, UNDER_TABLE).map((job) => historyItem(job, false, nameOf, now))
      }
    }
  }

  return view
}

function tableRow (printer, single, now, options) {
  const bucket = bucketOf(printer)
  const filename = printer.nextJob?.executable?.filename
  return {
    printer,
    bucket,
    current: IN_PROGRESS.includes(printer.status.stateFamily) ? nowItem(printer, single, now) : null,
    nowText: IDLE_TEXT[bucket] || '',
    nextFile: filename ? `${filename}${printer.queuedCount > 1 ? ` +${printer.queuedCount - 1}` : ''}` : 'Nothing queued',
    count: printer.queuedCount,
    canStart: !!(options.startNext && printer.canStartNext && filename)
  }
}

function historyItem (job, single, nameOf, now) {
  const when = formatAgo(job.updatedAt, now)
  return {
    id: job.id,
    file: job.executable?.filename || 'Unnamed job',
    status: job.status,
    side: single ? when : `${nameOf(job)} · ${when}`
  }
}
