// What the copies dialog says (Change Number of Copies on a batch, Print More Copies on a single print), from the
// print job's copies: how many are done, printing and waiting, and the fewest it can ask for
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
