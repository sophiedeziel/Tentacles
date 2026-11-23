// What the queue page's rows say, from the globalQueue query

const mm = (value) => Number(value).toLocaleString('en-US', { maximumFractionDigits: 1 })
const plural = (count, one, many) => `${count} ${count === 1 ? one : many}`

// "PLA Black", "PETG Any colour", "Unknown material White"
export function filamentText ({ material, colour }) {
  return `${material || 'Unknown material'} ${colour || 'Any colour'}`
}

// "PLA · Black", "PETG · Any colour" (the frames' way). `anyColour: false` leaves a missing colour out ("PETG").
export function filamentLabel ({ material, colour }, { separator = ' · ', anyColour = true } = {}) {
  const name = material || 'Unknown material'
  if (colour) return `${name}${separator}${colour}`
  return anyColour ? `${name}${separator}Any colour` : name
}

// The CSS colour of a filament's dot: its colour's name as typed ("Light Blue" → lightblue), when CSS knows it. Null
// for Any colour and for names CSS doesn't know ("Galaxy Black"): the dot is then drawn empty.
export function swatchColour (colour) {
  if (!colour) return null
  const name = colour.toLowerCase().replace(/\s+/g, '')
  if (typeof CSS !== 'undefined' && CSS.supports && !CSS.supports('color', name)) return null
  return name
}

// A print job's needs, one line per tool ("T1 PETG · Any colour" when it uses more than one), then its footprint
// ("120 × 80 mm"). `pending` while the G-code isn't read yet, `unknown` when it couldn't be.
export function needsView (needs) {
  if (needs.pending) return { pending: true, filaments: [], footprint: null }
  if (!needs.known) return { unknown: true, filaments: [], footprint: null }
  const multiTool = needs.filaments.length > 1
  return {
    filaments: needs.filaments.map((filament) => {
      const label = filamentLabel(filament)
      return { key: filament.tool, colour: filament.colour, text: multiTool ? `T${filament.tool} ${label}` : label }
    }),
    footprint: needs.footprint ? `${mm(needs.footprint.width)} × ${mm(needs.footprint.depth)} mm` : null
  }
}

// "× 10" and "4 left to start" for a batch; nothing for a single copy
export function batchView (job) {
  if (job.copies <= 1) return null
  return { size: `× ${job.copies}`, left: `${job.copiesLeftToStart} left to start` }
}

// "Copy 2 of 5" for a copy of a batch, null for a single print
export function copyText (print) {
  return print.printJob.copies > 1 ? `Copy ${print.copyNumber} of ${print.printJob.copies}` : null
}

// The copy a printer takes next of a job: the first one not handed out yet
export function nextCopyNumber (job) {
  return job.copies - job.copiesLeftToStart + 1
}

// "bracket_v3.gcode · copy 2 of 10", or the file alone for a single print (a Finished row)
export function printLabel (print) {
  const { file, copies } = print.printJob
  return copies > 1 ? `${file.filename} · copy ${print.copyNumber} of ${copies}` : file.filename
}

// "PLA Black loaded", or "No filament set"
export function loadedText (loadedFilaments = []) {
  if (loadedFilaments.length === 0) return 'No filament set'
  return `${loadedFilaments.map((filament) => `${filament.material} ${filament.colour}`).join(', ')} loaded`
}

// Whether the page has nothing under way: no job waiting, nothing printing and no bed to clear. Available printers
// and finished prints don't count.
export function isQueueEmpty (queue) {
  return queue.waiting.length === 0 && queue.printing.length === 0 && queue.printersToClear.length === 0
}

// Available Printers' line: how many printers are free (their bed cleared or not), and whether they take a job now
export function availableSummary (count, paused) {
  if (count === 0) return 'No printer free right now'
  const free = `${plural(count, 'printer', 'printers')} free`
  return paused ? `${free}, not taking jobs while dispatch is paused` : `${free} to take a job`
}

// "Copy 2 of 10 is finished and still on the bed": the print on a bed to clear (Printer.printOnBed, null when not
// known). Named by its file unless it is the file the printer takes next.
export function onBedText (print, takesNext) {
  if (!print) return 'Its last print is still on the bed'
  const sameFile = takesNext && takesNext.file.filename === print.printJob.file.filename
  const copy = copyText(print)
  let what = print.printJob.file.filename
  if (copy) what = sameFile ? copy : `${what} · ${copy.toLowerCase()}`
  if (print.result === 'FAILED') return `${what} failed and is still on the bed`
  if (print.result === 'CANCELLED') return `${what} was cancelled and is still on the bed`
  return `${what} is finished and still on the bed`
}

// Available Printers' Takes Next column: what the queue lines up for a printer (`printer.takesNext`, worked out as if
// dispatch ran). `toClear`: its bed is still to be cleared (`onBed`: the print on it).
export function takesNextView (printer, { paused, toClear = false, onBed = null }) {
  const job = printer.takesNext
  const detail = toClear ? onBedText(onBed, job) : null
  if (printer.takesJobs === false) return { text: 'Not taking jobs from the queue', detail }
  if (paused) {
    return {
      text: 'Nothing while dispatch is paused',
      detail: detail || (job ? `It takes ${job.file.filename} when dispatch resumes` : null)
    }
  }
  if (!job) return { text: 'Nothing waiting it can print', detail }
  if (toClear) return { text: `${job.file.filename}, once its bed is cleared`, detail }
  const copy = job.copies > 1 ? ` · copy ${nextCopyNumber(job)} of ${job.copies}` : ''
  return { text: `Starting ${job.file.filename}${copy}`, detail }
}

// "Prusa Mini is offline and takes no jobs.": an Available Printers footer line
export function offlineText (printer) {
  const family = printer.status?.stateFamily
  if (family === 'CONNECTING') return `${printer.name} is connecting and takes no jobs until it is back.`
  if (family === 'ERROR') return `${printer.name} is in error and takes no jobs.`
  return `${printer.name} is offline and takes no jobs.`
}

// Printing's line: "1 printing · 1 paused", "2 prints under way", "2 paused"
export function printingSummary (prints) {
  if (prints.length === 0) return null
  const paused = prints.filter((print) => print.printer.status?.stateFamily === 'PAUSED').length
  if (paused === 0) return `${plural(prints.length, 'print', 'prints')} under way`
  if (paused === prints.length) return `${paused} paused`
  return `${prints.length - paused} printing · ${paused} paused`
}

// Waiting's line: "5 jobs · 15 prints" (the copies left to start)
export function waitingSummary (jobs) {
  const prints = jobs.reduce((total, job) => total + job.copiesLeftToStart, 0)
  return `${plural(jobs.length, 'job', 'jobs')} · ${plural(prints, 'print', 'prints')}`
}

const isBound = (job) => job.samePrinter && Boolean(job.boundPrinter)

// "both copies", "all 4 copies"
const copiesWord = (count) => (count === 2 ? 'both copies' : `all ${count} copies`)

// A Waiting row's Printers column: how many printers can take it, then which ("All that can print it", their names)
// or, for a same-printer batch, how it goes ("Has the batch", "First ready one takes both copies")
export function printersView (job) {
  if (isBound(job)) return { title: job.boundPrinter.name, detail: 'Has the batch' }
  const count = job.eligiblePrinters.length
  if (count === 0) return { title: 'No printer', detail: 'None can print it' }
  const title = plural(count, 'printer', 'printers')
  if (job.samePrinter && job.copiesLeftToStart > 1) {
    return { title, detail: `First ready one takes ${copiesWord(job.copiesLeftToStart)}` }
  }
  if (job.allCapable) return { title, detail: 'All that can print it' }
  return { title, detail: job.eligiblePrinters.map((printer) => printer.name).join(', ') }
}

const DONE = (print) => print.result === 'COMPLETED'
const UNDER_WAY = (print) => print.status === 'ENQUEUED' || print.status === 'ACTIVE'

// An expanded batch's line: "2 done · 1 printing · 7 waiting", "All on Prusa MK4 · …" for a bound batch
export function batchSummary (job) {
  const failed = job.prints.filter((print) => print.result === 'FAILED').length
  const cancelled = job.prints.filter((print) => print.result === 'CANCELLED').length
  const parts = [
    `${job.prints.filter(DONE).length} done`,
    failed > 0 && `${failed} failed`,
    cancelled > 0 && `${cancelled} cancelled`,
    `${job.prints.filter(UNDER_WAY).length} printing`,
    `${job.copiesLeftToStart} waiting`
  ].filter(Boolean)
  if (isBound(job)) parts.unshift(`All on ${job.boundPrinter.name}`)
  return parts.join(' · ')
}

// The one row of an expanded batch for its copies not handed out yet: "Copies 4 to 10", the printer they go to and how
export function waitingCopiesView (job) {
  const left = job.copiesLeftToStart
  const first = job.copies - left + 1
  const label = left === 1 ? `Copy ${job.copies} of ${job.copies}` : `Copies ${first} to ${job.copies}`
  if (isBound(job)) {
    const detail = first > 1 ? `One after another, after copy ${first - 1}` : 'One after another'
    return { label, printer: job.boundPrinter.name, detail }
  }
  if (job.samePrinter) return { label, printer: 'Not assigned yet', detail: 'All on the first ready printer' }
  return { label, printer: 'Not assigned yet', detail: left === 1 ? 'Goes to the next ready printer' : 'Each goes to the next ready printer' }
}

// The statuses of a copy that count toward a print job's floor: done, or handed to a printer (starting, printing)
const FLOOR_STATUSES = ['COMPLETED', 'ENQUEUED', 'ACTIVE']
const UNDER_WAY_STATUSES = ['ENQUEUED', 'ACTIVE']

// The fewest copies a print job can ask for: the copies done and printing, and at least 1. The server refuses
// below it with the same floor (setPrintJobCopies); a failed copy can be given up.
export function copiesFloor (job) {
  return Math.max(1, job.prints.filter((print) => FLOOR_STATUSES.includes(print.status)).length)
}

// How many of a print job's copies are handed to a printer and not ended yet
export function copiesUnderWay (job) {
  return job.prints.filter((print) => UNDER_WAY_STATUSES.includes(print.status)).length
}
