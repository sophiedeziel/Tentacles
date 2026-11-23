// The one place a waiting job's What Happens Next (computed by the server, so the queue page and the printer page
// agree) turns into words. `next` is the PrintJob's whatHappensNext: a kind, and the printer when the kind names one.
//
// Returns { text, tone, loadFilament }:
// - tone: 'held' and 'paused' read as warnings, 'blocked' as an error, the others as plain text
// - loadFilament: whether the row offers Load Filament (BLOCKED, when some printer could print it once its filament
//   is changed)

// The printer a kind names. The server always sends it for these kinds; "A printer" covers a printer removed since.
const printerName = (next) => next.printer?.name || 'A printer'

const WORDS = {
  ON_HOLD: () => ({ text: 'On hold', tone: 'held' }),
  DISPATCH_PAUSED: () => ({ text: 'Dispatch paused', tone: 'paused' }),
  // BLOCKED also covers a job no printer can print at all (no eligible printer): no filament change helps then
  BLOCKED: (next, { eligibleCount }) => (eligibleCount > 0
    ? { text: 'No printer has the needed filament loaded', tone: 'blocked', loadFilament: true }
    : { text: 'No printer can print it', tone: 'blocked' }),
  NEXT_READY_PRINTER: (next, { copiesLeft }) => ({
    text: copiesLeft > 1 ? 'Each copy goes to the next ready printer' : 'Goes to the next ready printer'
  }),
  AFTER_CURRENT_PRINT: (next) => ({ text: `${printerName(next)} takes it when its print finishes` }),
  AFTER_BED_CLEARED: (next) => ({ text: `${printerName(next)} takes it once its bed is cleared` }),
  STARTING: (next) => ({ text: `Starting on ${printerName(next)}` }),
  BATCH_ON_PRINTER: (next) => ({ text: `${printerName(next)} prints the next copy when the current one finishes` }),
  BATCH_FIRST_READY_PRINTER: () => ({ text: 'The first ready printer takes all the copies' })
}

export const WHAT_HAPPENS_NEXT_KINDS = Object.keys(WORDS)

// `copiesLeft`: the copies not handed to a printer yet; `eligibleCount`: how many printers can print it.
// Null when nothing is left to happen (every copy printing or finished) or for a kind this page doesn't know yet.
export default function whatHappensNext (next, { copiesLeft = 1, eligibleCount = 0 } = {}) {
  const words = next && WORDS[next.kind]
  if (!words) return null
  return { tone: 'plain', loadFilament: false, ...words(next, { copiesLeft, eligibleCount }) }
}
