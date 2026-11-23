// What the queue page's confirmations say (antd Modal.confirm): Remove from Queue and Cancel Print, which can't be
// undone
import confirmationFor from '../Dashboard/widgets/Printer/confirmations'
import { copiesUnderWay } from './queueView'

const copies = (count) => (count === 1 ? 'copy' : 'copies')

// Remove from Queue: names the file and the copies it removes (the ones waiting to start). Copies printing go on.
export function removeConfirmation (job) {
  const waiting = job.copiesLeftToStart
  const underWay = copiesUnderWay(job)
  const removed = waiting === 1
    ? 'The copy waiting to start is removed.'
    : `The ${waiting} ${copies(waiting)} waiting to start are removed.`
  let goOn = ''
  if (underWay === 1) goOn = ' The copy printing now finishes.'
  else if (underWay > 1) goOn = ` The ${underWay} copies printing now finish.`

  return {
    title: `Remove ${job.file.filename} from the queue?`,
    body: `${removed}${goOn} The file stays in your library.`,
    ok: 'Remove from Queue',
    keep: 'Keep in Queue'
  }
}

// Cancel Print, worded as on the dashboard: the file shown on the row, where the printer got to
export function cancelConfirmation (print) {
  const status = print.printer.status || {}
  return confirmationFor('cancel', {
    name: print.printer.name,
    family: status.stateFamily,
    progress: Math.round(status.progress ?? print.progress ?? 0),
    headline: print.printJob.file.filename
  })
}
