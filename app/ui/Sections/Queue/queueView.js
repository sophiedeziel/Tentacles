// What the queue page's rows say, from the globalQueue query

const mm = (value) => Number(value).toLocaleString('en-US', { maximumFractionDigits: 1 })

// "PLA Black", "PETG Any colour", "Unknown material White"
export function filamentText ({ material, colour }) {
  return `${material || 'Unknown material'} ${colour || 'Any colour'}`
}

// A print job's needs, one line per tool ("T1 PETG Any colour" when it uses more than one), then its footprint
// ("120 × 80 mm"). `pending` while the G-code isn't read yet, `unknown` when it couldn't be.
export function needsView (needs) {
  if (needs.pending) return { pending: true, filaments: [], footprint: null }
  if (!needs.known) return { unknown: true, filaments: [], footprint: null }
  const multiTool = needs.filaments.length > 1
  return {
    filaments: needs.filaments.map((filament) => ({
      key: filament.tool,
      text: multiTool ? `T${filament.tool} ${filamentText(filament)}` : filamentText(filament)
    })),
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

// The latest finished print of each printer that has one, by printer id: what is on a bed to clear
export function lastPrintByPrinter (finished) {
  const prints = {}
  finished.forEach((print) => {
    if (!prints[print.printer.id]) prints[print.printer.id] = print
  })
  return prints
}
