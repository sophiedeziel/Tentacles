// The one place a waiting job's What Happens Next (computed by the server, so the queue page and the printer page
// agree) turns into words. The server sends, on each PrintJob, `whatHappensNext`: a kind, the printer when the kind
// names one, how many jobs that printer takes before this one (jobsAhead) and whether it waits for dispatch to resume
// first (dispatchPaused: the outcome is worked out as if dispatch ran). The words also read the job: its copies left
// to start, whether it is a same-printer batch, the printers that can print it and its needs.
//
//   whatHappensNext(job)                          // the queue page: "Prusa MK4 takes it once its bed is cleared"
//   whatHappensNext(job, { printerId: mk4.id })  // the printer page of the MK4: "Starts once the bed is cleared"
//
// With `printerId`, a kind naming that printer is said from its own page (no name, "the bed"); a kind naming another
// printer, or none, reads as on the queue page.
//
// Returns null when nothing is left to happen (every copy printing or finished) or for a kind it doesn't know, else
// { text, icon, loadFilament }:
// - icon: 'next' (a printer takes it as soon as it is free: a check), 'waiting' (it waits for a print, the next ready
//   printer or the jobs ahead: a clock), 'blocked' (a warning) or 'held' (a pause mark)
// - loadFilament: whether the row offers Load Filament (BLOCKED, when some printer could print it once its filament
//   is changed)

import { filamentLabel } from './queueView'

const RESUME = 'Waiting for dispatch to resume'

const jobsWord = (count) => (count === 1 ? '1 job' : `${count} jobs`)

// "both copies", "all 4 copies"; "it" for a single one
const allCopies = (count) => {
  if (count <= 1) return 'it'
  return count === 2 ? 'both copies' : `all ${count} copies`
}

// The printer a kind names. The server always sends it for these kinds; "A printer" covers a printer removed since.
const printerName = (next) => next.printer?.name || 'A printer'

// What a batch takes from its printer: the next copy, every copy left (a same-printer batch takes them all), or it
const whatItTakes = (job) => {
  const left = job.copiesLeftToStart ?? 1
  if (left <= 1) return 'it'
  return job.samePrinter ? allCopies(left) : 'the next copy'
}

// The copy a printer finishes before the next one of its batch: the last one handed out
const copyUnderWay = (job) => (job.copies ?? 1) - (job.copiesLeftToStart ?? 1)

// Whether the batch has a copy printing (unknown without its copies: the printer page's rows carry none). When it
// has none, its printer finishes another job before the next copy.
const batchPrinting = (job) => !job.prints || job.prints.some((print) => ['ENQUEUED', 'ACTIVE'].includes(print.status))

// "PLA White", "PETG", "PLA White and PETG Black": what no printer has loaded
const neededText = (needs) => {
  const filaments = (needs?.known ? needs.filaments : []).filter((filament) => filament.material)
  if (filaments.length === 0) return 'its filament'
  return filaments.map((filament) => filamentLabel(filament, { separator: ' ', anyColour: false })).join(' and ')
}

const blocked = (job) => {
  if ((job.eligiblePrinters?.length ?? 0) === 0) return { text: 'Blocked: no printer can print it.', icon: 'blocked' }
  return { text: `Blocked: no printer has ${neededText(job.needs)} loaded.`, icon: 'blocked', loadFilament: true }
}

const ahead = (who, next) => `${who}, after ${jobsWord(next.jobsAhead)} ahead of it`

// The queue page's words, a printer named by its name
const WORDS = {
  ON_HOLD: () => ({ text: 'On hold', icon: 'held' }),
  BLOCKED: (next, job) => blocked(job),
  NEXT_READY_PRINTER: (next, job, paused) => {
    const goes = `${(job.copiesLeftToStart ?? 1) > 1 ? 'each goes' : 'goes'} to the next ready printer`
    return { text: paused ? `${RESUME}, then ${goes}` : capitalize(goes), icon: 'waiting' }
  },
  BATCH_FIRST_READY_PRINTER: (next, job, paused) => {
    const takes = `the first ready printer takes ${allCopies(job.copiesLeftToStart ?? 1)}`
    return { text: paused ? `${RESUME}, then ${takes}` : capitalize(takes), icon: 'waiting' }
  },
  STARTING: (next, job, paused) => ({
    text: paused ? `Ready for ${printerName(next)} when dispatch resumes` : `Starting on ${printerName(next)}`,
    icon: 'next'
  }),
  AFTER_BED_CLEARED: (next, job, paused) => {
    const p = printerName(next)
    if (paused) return { text: `Ready for ${p} when dispatch resumes and its bed is cleared`, icon: 'next' }
    return { text: `${p} takes ${whatItTakes(job)} once its bed is cleared`, icon: 'next' }
  },
  AFTER_CURRENT_PRINT: (next, job, paused) => {
    const p = printerName(next)
    if (next.jobsAhead > 0) return { text: paused ? `${RESUME}. ${ahead(p, next)}` : ahead(p, next), icon: 'waiting' }
    if (paused) return { text: `${RESUME}, then for ${p} to finish its print`, icon: 'waiting' }
    return { text: `${p} takes ${whatItTakes(job)} when its print finishes`, icon: 'waiting' }
  },
  BATCH_ON_PRINTER: (next, job, paused) => {
    const p = printerName(next)
    const current = copyUnderWay(job)
    if (current < 1) return { text: `${p} prints the next copy when the current one finishes`, icon: 'waiting' }
    if (!batchPrinting(job)) {
      if (paused) return { text: `${RESUME}, then for ${p} to finish its print`, icon: 'waiting' }
      return { text: `${p} prints copy ${current + 1} when its print finishes`, icon: 'waiting' }
    }
    if (paused) return { text: `${RESUME}, then for ${p} to finish copy ${current}`, icon: 'waiting' }
    return { text: `${p} prints copy ${current + 1} when copy ${current} finishes`, icon: 'waiting' }
  }
}

// The printer page's words for the kinds naming its own printer: "Starts once the bed is cleared"
const OWN_WORDS = {
  ON_HOLD: () => ({ text: 'On hold until released', icon: 'held' }),
  STARTING: (next, job, paused) => ({ text: paused ? 'Starts when dispatch resumes' : 'Starting', icon: 'next' }),
  AFTER_BED_CLEARED: (next, job, paused) => ({
    text: paused ? 'Starts when dispatch resumes and the bed is cleared' : 'Starts once the bed is cleared',
    icon: 'next'
  }),
  AFTER_CURRENT_PRINT: (next, job, paused) => {
    if (next.jobsAhead > 0) {
      const text = `After ${jobsWord(next.jobsAhead)} ahead of it`
      return { text: paused ? `${RESUME}. ${text}` : text, icon: 'waiting' }
    }
    return {
      text: paused ? 'Starts when dispatch resumes and the current print finishes' : 'Starts when the current print finishes',
      icon: 'waiting'
    }
  },
  BATCH_ON_PRINTER: (next, job, paused) => {
    const current = copyUnderWay(job)
    if (current < 1) return { text: 'Prints the next copy when the current one finishes', icon: 'waiting' }
    if (!batchPrinting(job)) return { text: `Prints copy ${current + 1} when the current print finishes`, icon: 'waiting' }
    if (paused) return { text: `${RESUME}, then prints copy ${current + 1}`, icon: 'waiting' }
    return { text: `Prints copy ${current + 1} when copy ${current} finishes`, icon: 'waiting' }
  }
}

function capitalize (text) {
  return text.charAt(0).toUpperCase() + text.slice(1)
}

export const WHAT_HAPPENS_NEXT_KINDS = Object.keys(WORDS)

// The kinds of the Waiting filters (the queue page's Segmented): On Hold is ON_HOLD, Blocked is BLOCKED (no printer
// has its filament loaded, or none can print it), Ready is every other kind (some printer takes it with the filament
// it has, now or after what is ahead of it). All shows every job.
export const WAITING_FILTERS = ['All', 'Ready', 'Blocked', 'On Hold']

export function matchesFilter (job, filter) {
  const kind = job.whatHappensNext?.kind
  if (filter === 'On Hold') return kind === 'ON_HOLD'
  if (filter === 'Blocked') return kind === 'BLOCKED'
  if (filter === 'Ready') return Boolean(kind) && kind !== 'ON_HOLD' && kind !== 'BLOCKED'
  return true
}

// `job`: a PrintJob with whatHappensNext, copies, copiesLeftToStart, samePrinter, eligiblePrinters and needs.
// `printerId`: the printer whose page it is shown on, if any.
export default function whatHappensNext (job, { printerId = null } = {}) {
  const next = job?.whatHappensNext
  if (!next) return null
  const own = printerId != null && (next.kind === 'ON_HOLD' || next.printer?.id === printerId)
  const words = (own && OWN_WORDS[next.kind]) || WORDS[next.kind]
  if (!words) return null
  // Blocked and held read the same whether dispatch runs or not
  const paused = Boolean(next.dispatchPaused) && next.kind !== 'ON_HOLD' && next.kind !== 'BLOCKED'
  return { loadFilament: false, ...words(next, job, paused) }
}
