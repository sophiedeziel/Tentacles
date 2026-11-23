import { gql } from '@apollo/client'

// The queue page's actions. Each answers `success` and `errors` (UserError: a refusal's message, never raised).
// useQueueActions shows the errors and reloads globalQueue after each one: the payloads select only what keeps the
// cache right until the reload lands (a print job's own fields, merged by id).

const PRINT_JOB_RESULT = gql`
  fragment QueuePrintJobResult on PrintJob { id copies held samePrinter boundPrinter { id name } }
`

const printJobAction = (mutation, operation) => gql`
  mutation Queue${operation}($id: ID!) {
    ${mutation}(input: { id: $id }) {
      success
      errors { field message }
      printJob { ...QueuePrintJobResult }
    }
  }
  ${PRINT_JOB_RESULT}
`

// Drag to reorder (beforeId: the row it now sits right above), Move to Top / Move to Bottom (to: TOP, BOTTOM).
// The payload's globalQueue lands under the mutation, not Query.globalQueue: the page reloads instead.
export const MOVE_PRINT_JOB = gql`
  mutation QueueMovePrintJob($id: ID!, $to: MovePrintJobTo, $beforeId: ID) {
    movePrintJob(input: { id: $id, to: $to, beforeId: $beforeId }) {
      success
      errors { field message }
    }
  }
`

export const HOLD_PRINT_JOB = printJobAction('holdPrintJob', 'HoldPrintJob')
export const RELEASE_PRINT_JOB = printJobAction('releasePrintJob', 'ReleasePrintJob')
// Release to Other Printers: a same-printer batch goes back to any printer
export const UNBIND_PRINT_JOB = printJobAction('unbindPrintJob', 'UnbindPrintJob')

// Remove from Queue: the waiting copies (copies printing go on)
export const REMOVE_PRINT_JOB = gql`
  mutation QueueRemovePrintJob($id: ID!) {
    removePrintJob(input: { id: $id }) {
      success
      errors { field message }
      deletedPrintJobId
    }
  }
`

// Never below the copies done and printing: the server refuses with the reason
export const SET_PRINT_JOB_COPIES = gql`
  mutation QueueSetPrintJobCopies($id: ID!, $copies: Int!) {
    setPrintJobCopies(input: { id: $id, copies: $copies }) {
      success
      errors { field message }
      printJob { ...QueuePrintJobResult }
    }
  }
  ${PRINT_JOB_RESULT}
`

// Requeue from Finished: the file again, one copy, at the bottom
export const ADD_TO_QUEUE = gql`
  mutation QueueAddToQueue($fileId: ID!, $copies: Int) {
    addToQueue(input: { fileId: $fileId, copies: $copies }) {
      success
      errors { field message }
      printJob { id }
    }
  }
`

// Bed Cleared: stamps the print on the printer's bed, so the printer can take its next one. expectedPrintId: the print
// the person was shown (printOnBed); refused when the bed now holds another one
export const CONFIRM_BED_CLEARED = gql`
  mutation QueueConfirmBedCleared($printerId: ID!, $expectedPrintId: ID!) {
    confirmBedCleared(input: { printerId: $printerId, expectedPrintId: $expectedPrintId }) {
      success
      errors { field message }
    }
  }
`

// The dispatch switch. The payload's globalQueue lands under the mutation, not Query.globalQueue: the switch shows
// dispatchPaused from the page's query, reloaded after.
export const PAUSE_DISPATCH = gql`
  mutation QueuePauseDispatch {
    pauseDispatch(input: {}) {
      success
      errors { field message }
    }
  }
`

export const RESUME_DISPATCH = gql`
  mutation QueueResumeDispatch {
    resumeDispatch(input: {}) {
      success
      errors { field message }
    }
  }
`
