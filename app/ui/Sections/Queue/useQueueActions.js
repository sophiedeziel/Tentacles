import { useCallback, useMemo } from 'react'
import { useApolloClient } from '@apollo/client/react'
import { App } from 'antd'

import { ACTIONS } from '../Dashboard/graphql/actions'
import {
  ADD_TO_QUEUE, HOLD_PRINT_JOB, MOVE_PRINT_JOB, PAUSE_DISPATCH, RELEASE_PRINT_JOB,
  REMOVE_PRINT_JOB, RESUME_DISPATCH, SET_PRINT_JOB_COPIES, UNBIND_PRINT_JOB
} from './graphql/actions'

// A queue mutation's errors are UserErrors ({ field, message }), a printer control's plain strings
const messageOf = (error) => (typeof error === 'string' ? error : error.message)

// Runs one mutation the way every queue action does: a refusal (success false) or a failed request shows as an antd
// message with the server's words, then `reload` runs, after a success too (the queueChanged push that follows is
// coalesced with it). Resolves to whether it was saved, once the reload landed, so a row moved ahead of the server
// can wait for the real order.
export function useQueueMutation (reload) {
  const client = useApolloClient()
  const { message } = App.useApp()

  return useCallback(async (mutation, variables, field, { failure = 'It could not be saved' } = {}) => {
    let saved = false
    try {
      const { data } = await client.mutate({ mutation, variables })
      const payload = data[field]
      saved = payload.success
      if (!saved) {
        const messages = payload.errors.map(messageOf)
        if (messages.length === 0) messages.push(failure)
        messages.forEach((text) => message.error(text))
      }
    } catch (error) {
      message.error(`${failure}: ${error.message}`)
    }
    await reload?.()
    return saved
  }, [client, message, reload])
}

// What the confirmation of a print control saw: the file shown on the row, which is the name the copy was uploaded
// under and the printer reports back. The server refuses when the printer prints something else by then.
const expectedFile = (print) => ({ printerId: print.printer.id, expectedFileName: print.printJob.file.filename })

// Every action of the queue page, each resolving to whether it was saved (see useQueueMutation):
// - print jobs: move(job, { beforeId } | { to: 'TOP' | 'BOTTOM' }), hold(job), release(job), unbind(job) (Release to
//   Other Printers), remove(job) (the waiting copies), setCopies(job, copies, { samePrinter }) (samePrinter left out:
//   unchanged), requeue(file) (one copy, at the bottom)
// - copies printing: pausePrint(print), resumePrint(print), cancelPrint(print), with the file shown as expectedFileName
// - printers: reconnect(printer) (connectPrinter when offline, reconnectPrinter when in error)
// - the fleet: pauseDispatch(), resumeDispatch()
// Bed Cleared has its own hook and modal (BedCleared/useBedCleared), shared with the printer page.
export default function useQueueActions (reload) {
  const run = useQueueMutation(reload)

  return useMemo(() => {
    const printJob = (document, field, failure) => (job) => run(document, { id: job.id }, field, { failure })
    const printControl = (key, failure) => (print) => {
      const { document, mutation } = ACTIONS[key]
      return run(document, expectedFile(print), mutation, { failure })
    }

    return {
      move: (job, target) => run(MOVE_PRINT_JOB, { id: job.id, ...target }, 'movePrintJob', { failure: 'Move failed' }),
      hold: printJob(HOLD_PRINT_JOB, 'holdPrintJob', 'Hold failed'),
      release: printJob(RELEASE_PRINT_JOB, 'releasePrintJob', 'Release failed'),
      unbind: printJob(UNBIND_PRINT_JOB, 'unbindPrintJob', 'Release to Other Printers failed'),
      remove: printJob(REMOVE_PRINT_JOB, 'removePrintJob', 'Remove from Queue failed'),
      setCopies: (job, copies, { samePrinter = null } = {}) => run(SET_PRINT_JOB_COPIES,
        { id: job.id, copies, samePrinter }, 'setPrintJobCopies',
        { failure: 'The copies could not be changed' }),
      requeue: (file) => run(ADD_TO_QUEUE, { fileId: file.id, copies: 1 }, 'addToQueue', { failure: 'Requeue failed' }),
      pausePrint: printControl('pause', 'Pause Print failed'),
      resumePrint: printControl('resume', 'Resume Print failed'),
      cancelPrint: printControl('cancel', 'Cancel Print failed'),
      // Reconnect (an offline printer's line): a printer in error reconnects, an offline one connects again
      reconnect: (printer) => {
        const { document, mutation } = ACTIONS[printer.status?.stateFamily === 'ERROR' ? 'reconnect' : 'connect']
        return run(document, { printerId: printer.id }, mutation, { failure: 'Reconnect failed' })
      },
      pauseDispatch: () => run(PAUSE_DISPATCH, {}, 'pauseDispatch', { failure: 'Pausing dispatch failed' }),
      resumeDispatch: () => run(RESUME_DISPATCH, {}, 'resumeDispatch', { failure: 'Resuming dispatch failed' })
    }
  }, [run])
}
