// The rules of the Add to Queue form (and of the Edit page, its second mode), apart from React: what the G-code says
// about the filament and how it fills the fields, which printers are selected, how a printer's fit and the summary
// read, and what is saved.

import { formatPrintTime } from '../../../utils/time'
import { hexColour, nearestColourName } from './colours'

// The Colour field's "Any Colour": a value the person picked (so never replaced by the G-code's), saved as null
export const ANY_COLOUR = 'ANY'

// The filament the G-code says, from its summary (single-filament files: its first tool), each value null when it
// doesn't say:
// - status: the summary's (PENDING while it is read, FAILED when it couldn't be), null for a file that isn't G-code
// - material: one of the closed list; raw: the material as the slicer wrote it when it isn't in the list ("PCTG")
// - colour: the named colour nearest its hex ("Black"); hex: the hex itself, for the swatch
// - tools: how many filaments the file uses (several: the materials stay the G-code's, phase 9)
export function gcodeFilament (summary) {
  const ready = summary?.status === 'READY'
  const tool = ready ? summary.tools[0] : null
  return {
    status: summary?.status ?? null,
    material: tool?.material ?? null,
    raw: (!tool?.material && tool?.materialRaw) || null,
    colour: nearestColourName(tool?.colourHex),
    hex: hexColour(tool?.colourHex),
    tools: ready ? Math.max(summary.tools.length, summary.toolCount ?? 0) : 0
  }
}

// The fields once the G-code is read: an empty field takes the G-code's value; one with a value keeps it, whatever
// the G-code says (never replaced, see the Reset buttons)
export function fillEmpty (fields, gcode) {
  return {
    material: fields.material ?? gcode.material,
    colour: fields.colour ?? gcode.colour
  }
}

// What is saved: Any Colour (or an empty field) is null, which any colour matches
export const savedColour = (colour) => (colour && colour !== ANY_COLOUR ? colour : null)

// The line under the Material field
export function materialHint (material, gcode) {
  if (gcode.status === 'PENDING') return 'Reading the G-code…'
  if (gcode.status === 'FAILED') return "The G-code couldn't be read. Pick the material it prints with"
  if (gcode.tools > 1) return 'Several filaments: each one is the material its G-code says'
  if (gcode.raw && !material) return `The G-code says ${gcode.raw}, which is not a material the queue can match`
  if (gcode.material && material === gcode.material) return 'From the G-code'
  if (gcode.material) return `The G-code says ${gcode.material}`
  if (gcode.raw) return `The G-code says ${gcode.raw}`
  return "The G-code doesn't say"
}

// The line under the Colour field (the swatch of the G-code's hex goes beside it)
export function colourHint (colour, gcode) {
  if (gcode.status === 'PENDING') return 'Reading the G-code…'
  const says = gcode.colour ? ` The G-code says ${gcode.colour}` : ''
  if (colour === ANY_COLOUR || !colour) return `Any colour is accepted.${says}`
  if (gcode.colour && colour === gcode.colour) return 'From the G-code. Any Colour lets more printers take it'
  return `Asked for.${says}`
}

// The printers that can be selected: every printer but those it can never print on (hard limits)
const selectable = (fits) => fits.filter((fit) => !fit.hardLimit).map((fit) => fit.printer.id)

// The printers selected. Untouched (`selection.touched` false), the automatic selection: every printer that can print
// it, recomputed with the fits. Once the person ticks or clears one, their ticks (`selection.ticked`), which survive a
// recompute; a ticked printer that can no longer print it is left out, and back if it can again.
export function selectedPrinterIds (fits, selection) {
  const ids = selectable(fits)
  if (!selection.touched) return ids
  return ids.filter((id) => selection.ticked.includes(id))
}

// The selection after a tick (or an untick) of one printer, from what is selected now
export function tick (fits, selection, printerId, checked) {
  const ids = selectedPrinterIds(fits, selection)
  return { touched: true, ticked: checked ? [...new Set([...ids, printerId])] : ids.filter((id) => id !== printerId) }
}

export const selectAll = (fits) => ({ touched: true, ticked: selectable(fits) })
export const clearAll = () => ({ touched: true, ticked: [] })

const CHANGES = ['NO_FILAMENT', 'WRONG_MATERIAL', 'WRONG_COLOUR']
const lowerFirst = (text) => text.charAt(0).toLowerCase() + text.slice(1)

// "PLA Black loaded", what its first slot holds (a single-filament file prints from it)
const loadedText = (printer) => {
  const loaded = (printer.loadedFilaments ?? []).find((filament) => filament.slot === 1)
  if (!loaded) return 'No filament loaded'
  return `${[loaded.material, loaded.colour].filter(Boolean).join(' ')} loaded`
}

// A printer's row: { mark, text }, the mark 'ready' (a check), 'waiting' (a clock) or 'cannot'
export function fitView (fit) {
  switch (fit.result) {
    case 'READY':
      return { mark: 'ready', text: `Can print it. ${loadedText(fit.printer)}` }
    case 'AFTER_FILAMENT_CHANGE':
      return { mark: 'waiting', text: `Can print it after a filament change. ${loadedText(fit.printer)}` }
    case 'AFTER_RECONNECT': {
      const change = fit.reasons.some((reason) => CHANGES.includes(reason.code))
      return { mark: 'waiting', text: `Can print it once it reconnects${change ? ' and its filament is set' : ''}` }
    }
    default:
      return {
        mark: 'cannot',
        text: `Can't print it: ${fit.reasons.map((reason) => lowerFirst(reason.message)).join('; ')}`
      }
  }
}

const plural = (count, word) => `${count} ${word}${count === 1 ? '' : 's'}`

const grams = (value) => `${value < 10 ? value.toFixed(1) : Math.round(value)} g`
const metres = (value) => `${value < 10 ? value.toFixed(1) : Math.round(value)} m`

// "180 g · 60 m", with Not known for a value that isn't (null when neither is)
export function amountText (gramsValue, metresValue) {
  if (gramsValue == null && metresValue == null) return null
  return [gramsValue, metresValue].map((value, index) => {
    if (value == null) return 'Not known'
    return index === 0 ? grams(value) : metres(value)
  }).join(' · ')
}

// The Summary card's lines, from the queueEstimate. `readyPrinters`: the selected printers that can print it with
// the filament they have, for the copies printed at once.
export function summaryView (estimate, { samePrinter, readyPrinters }) {
  const copies = estimate.copiesToPrint
  const queueNow = {
    title: `${estimate.printing} printing · ${plural(estimate.waitingJobs, 'job')} waiting`,
    detail: estimate.jobsAhead > 0
      ? `Ahead of this job: ${plural(estimate.jobsAhead, 'job')} · ${plural(estimate.printsAhead, 'print')}`
      : 'Nothing ahead of this job'
  }

  const filament = {
    title: amountText(estimate.filamentGrams, estimate.filamentMetres) ?? 'Not known',
    lines: estimate.filaments.map((each) => ({
      key: each.tool,
      material: each.material,
      colour: each.colour,
      amount: amountText(each.grams, each.metres)
    }))
  }

  let detail = null
  if (copies > 1 && estimate.printSeconds != null) {
    const atOnce = samePrinter ? 1 : Math.min(copies, readyPrinters)
    const each = estimate.printSeconds / copies
    detail = atOnce > 1
      ? `All copies, about ${formatPrintTime(Math.ceil(copies / atOnce) * each)} on ${atOnce} printers at once`
      : 'All copies, one after another'
  }
  const printTime = {
    title: estimate.printSeconds != null ? formatPrintTime(estimate.printSeconds) : 'Not known',
    detail
  }

  return { queueNow, filament, printTime }
}

// The variables addToQueue (and queueEstimate) take from the form. printerIds: left out (null) while the automatic
// selection is untouched, so the job is for every printer that can print it, printers added later included.
export function jobVariables ({ copies, material, colour, samePrinter, position, held }, { fits, selection }) {
  return {
    copies,
    material: material || null,
    colour: savedColour(colour),
    samePrinter,
    printerIds: selection.touched ? selectedPrinterIds(fits, selection) : null,
    position,
    held
  }
}

// The Edit page's form, from the print job as saved: its material (null: the G-code's, filled like a new job's), its
// colour (null: Any Colour, a value the G-code never replaces), and its printers: untouched for a job every printer
// that can print it may take (all_capable), its list ticked otherwise. Its position is read-only (Move to Top, Move
// to Bottom), sent as BOTTOM, which the estimate ignores for a job edited.
export function editedJob (job) {
  return {
    copies: job.copies,
    material: job.material ?? null,
    colour: job.colour ?? ANY_COLOUR,
    samePrinter: job.samePrinter,
    position: 'BOTTOM',
    held: job.held,
    selection: job.allCapable
      ? { touched: false, ticked: [] }
      : { touched: true, ticked: job.printers.map((printer) => printer.id) }
  }
}

// What updatePrintJob takes from the form's variables: every option but the file, its place and its hold
export function updateVariables (id, { copies, material, colour, samePrinter, printerIds }) {
  return { id, copies, material, colour, samePrinter, printerIds }
}
