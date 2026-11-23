// What the copies dialog says (Change Number of Copies on a batch, Print More Copies on a single print), from the
// print job's copies: how many are done, printing and waiting, and the fewest it can ask for
import { formatPrintTime } from '../../../utils/time'
import { copiesFloor } from '../queueView'

const UNDER_WAY = ['ENQUEUED', 'ACTIVE']

const cp = (count) => `${count} ${count === 1 ? 'copy' : 'copies'}`
const Cp = (count) => `${count} ${count === 1 ? 'Copy' : 'Copies'}`

// Done, printing and waiting copies of a print job
export function copyCounts (job) {
  return {
    done: job.prints.filter((print) => print.status === 'COMPLETED').length,
    printing: job.prints.filter((print) => UNDER_WAY.includes(print.status)).length,
    waiting: job.copiesLeftToStart
  }
}

// "The lowest is 3: 2 copies are done and 1 is printing, and those can't be taken back. To stop the copy that is
// printing, use Cancel Print in its row's menu." Null when nothing is done or printing.
export function floorText (job) {
  const { done, printing } = copyCounts(job)
  if (done + printing === 0) return null
  const parts = [
    done > 0 && `${cp(done)} ${done === 1 ? 'is' : 'are'} done`,
    printing > 0 && `${printing} ${printing === 1 ? 'is' : 'are'} printing`
  ].filter(Boolean)
  const kept = done + printing === 1 ? 'and it can\'t be taken back' : 'and those can\'t be taken back'
  const stop = printing === 0
    ? ''
    : ` To stop ${printing === 1 ? 'the copy that is' : 'the copies that are'} printing, use Cancel Print in ` +
      `${printing === 1 ? 'its row\'s menu' : 'their rows\' menus'}.`
  return `The lowest is ${copiesFloor(job)}: ${parts.join(' and ')}, ${kept}.${stop}`
}

// What setting `total` copies does to the waiting ones: "Adds 2 copies to the 7 waiting.", "Removes 3 copies from
// the 7 waiting. 4 stay in the queue.", "Removes all 7 waiting copies. The copy that is printing finishes."
export function effectText (job, total) {
  const { printing, waiting } = copyCounts(job)
  const diff = total - job.copies
  if (diff === 0) return 'No change.'
  if (diff > 0) return waiting > 0 ? `Adds ${cp(diff)} to the ${waiting} waiting.` : `Adds ${cp(diff)}.`
  const left = waiting + diff
  if (left > 0) return `Removes ${cp(-diff)} from the ${waiting} waiting. ${left} ${left === 1 ? 'stays' : 'stay'} in the queue.`
  let after = ''
  if (printing === 1) after = ' The copy that is printing finishes.'
  else if (printing > 1) after = ` The ${printing} copies printing finish.`
  return `Removes all ${waiting} waiting ${waiting === 1 ? 'copy' : 'copies'}.${after}`
}

// The dialog's words for a print job at `total` copies. A single print asks for more copies (it becomes a batch); a
// batch changes its number of copies, never below its floor (copiesFloor: the server's too).
export function copiesDialog (job, total) {
  const filename = job.file.filename
  if (job.copies === 1) {
    return {
      title: `Print more copies of ${filename}`,
      min: Math.max(2, copiesFloor(job)),
      change: `Now 1 copy. ${Math.max(0, total - 1)} more will be added.`,
      note: 'The job becomes a batch. The added copies keep its filament, printers and place in the queue.',
      ok: `Print ${Cp(total)}`,
      keep: 'Keep 1 Copy',
      unchanged: total === 1
    }
  }
  return {
    title: `Change the number of copies of ${filename}`,
    min: copiesFloor(job),
    change: effectText(job, total),
    note: floorText(job),
    ok: `Set to ${Cp(total)}`,
    keep: `Keep ${Cp(job.copies)}`,
    unchanged: total === job.copies
  }
}

// What one copy uses, from its print job (its material, null for the G-code's) and its file's G-code summary:
// { grams, seconds, material }, each null when it isn't known (a summary pending or failed, a value the slicer didn't
// write). The material is the job's, else what its G-code says ("PLA"). A file with several filaments prints with
// the materials its G-code says whatever the job asks (phase 9), so they're all named: "PLA, PETG".
export function copyUse (printJob) {
  const summary = printJob?.file?.gcodeSummary
  if (summary?.status !== 'READY') return { grams: null, seconds: null, material: printJob?.material ?? null }
  const materials = [...new Set(summary.tools.map((tool) => tool.material).filter(Boolean))]
  const several = summary.tools.length > 1
  return {
    grams: summary.filamentGrams ?? null,
    seconds: summary.printSeconds ?? null,
    material: (several ? null : printJob.material) ?? (materials.join(', ') || null)
  }
}

const grams = (value) => `${value < 10 ? value.toFixed(1) : Math.round(value)} g`

// "84 g of PETG" for `count` copies, null when not known
function filamentFor (use, count) {
  if (use.grams == null) return null
  const amount = grams(use.grams * count)
  return use.material ? `${amount} of ${use.material}` : amount
}

// "6 h 20 min" for `count` copies, null when not known
const timeFor = (use, count) => (use.seconds == null ? null : formatPrintTime(use.seconds * count))

// "4 copies waiting, after the one printing now": the copies a batch still has to print at `total`
function stillToPrint (waiting, printing) {
  const copies = waiting === 0 ? 'No copies waiting' : `${cp(waiting)} waiting`
  if (printing === 0) return copies
  if (waiting === 0) return `${copies}. ${printing === 1 ? 'The one printing now finishes' : `The ${printing} printing now finish`}`
  return `${copies}, after ${printing === 1 ? 'the one' : `the ${printing}`} printing now`
}

// The dialog's estimate box at `total` copies, as { label, value } rows, a row left out when its value isn't known
// (`use`: copyUse). A single print (Print More Copies): what the added copies use. A batch (Change Number of Copies):
// what its waiting copies still need, the copies printing aside.
export function estimateRows (job, total, use) {
  if (job.copies === 1) {
    const added = Math.max(0, total - 1)
    return [
      { label: 'Added filament', value: filamentFor(use, added) },
      { label: 'Added print time', value: timeFor(use, added) }
    ].filter((row) => row.value)
  }
  const { printing, waiting } = copyCounts(job)
  const left = Math.max(0, waiting + total - job.copies)
  return [
    { label: 'Still to print', value: stillToPrint(left, printing) },
    { label: 'Filament left to use', value: filamentFor(use, left) },
    { label: 'Print time left', value: timeFor(use, left) }
  ].filter((row) => row.value)
}
