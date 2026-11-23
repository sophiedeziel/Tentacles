import { gql } from '@apollo/client'

// An Up Next row: what the queue page's Waiting row shows, but its copies (the queue page has them) and with its
// place in the queue (waitingPosition, the queue page's "#")
const UP_NEXT_FIELDS = gql`
  fragment PrinterQueueJobFields on PrintJob {
    id
    waitingPosition
    copies
    copiesLeftToStart
    held
    samePrinter
    file { id filename isDeleted }
    boundPrinter { id name }
    needs {
      pending
      known
      colour
      filaments { tool material colour }
      footprint { width depth }
    }
    eligiblePrinters { id name }
    whatHappensNext { kind printer { id name } jobsAhead dispatchPaused }
  }
`

// The printer page's part of the global queue (only asked while it is on): whether the printer takes jobs, the
// print still on its bed (the banner's "copy 2 of 10 is done"), the job it takes next (highlighted in Up Next, and the
// Bed Cleared modal's "Next for it"), the waiting jobs it can take and the ones it skips with why, and how many
// waiting jobs ask for each loaded filament (Loaded Filament's hint). dispatchPaused: what the Bed Cleared modal says.
export const PRINTER_QUEUE = gql`
  query PrinterDetailsQueue($id: ID!) {
    globalQueue { dispatchPaused }
    printer(id: $id) {
      id
      name
      takesJobs
      bedNeedsClearing
      printOnBed { id copyNumber result printJob { id copies file { id filename isDeleted } } }
      takesNext { id copies copiesLeftToStart file { id filename } }
      upNext { ...PrinterQueueJobFields }
      skipped {
        reasons
        printJob { id waitingPosition copies copiesLeftToStart file { id filename isDeleted } }
      }
      loadedFilaments { slot material colour waitingJobsAskingCount }
    }
  }
  ${UP_NEXT_FIELDS}
`

// The Takes Jobs switch. Refused (in errors) while the global queue is off.
export const SET_PRINTER_TAKES_JOBS = gql`
  mutation PrinterDetailsSetTakesJobs($printerId: ID!, $takesJobs: Boolean!) {
    setPrinterTakesJobs(input: { printerId: $printerId, takesJobs: $takesJobs }) {
      success
      errors { field message }
      printer { id takesJobs }
    }
  }
`
