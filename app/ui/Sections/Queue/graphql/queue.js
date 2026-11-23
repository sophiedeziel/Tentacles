import { gql } from '@apollo/client'

import { PRINTER_FIELDS } from '../../Dashboard/graphql/dashboard'

// How many finished prints the page lists, the latest first (the server returns at most 50)
export const FINISHED_ROWS = 10

// Whether the global queue is on: globalQueue is null while its flag is off. Cheap (one setting read) and cached, so
// the side menu and the routes share one request.
export const GLOBAL_QUEUE_ENABLED = gql`
  query GlobalQueueEnabled {
    globalQueue { dispatchPaused }
  }
`

// A copy handed to a printer (Printing, Finished). Its printer carries the dashboard's printer fields, which
// printerStatusChanged pushes: Apollo merges them by id, so state and progress stay live without a refetch.
export const PRINT_FIELDS = gql`
  fragment QueuePrintFields on Print {
    id
    copyNumber
    status
    progress
    startedAt
    finishedAt
    result
    printer { ...DashboardPrinterFields }
    printJob { id copies file { id filename isDeleted } }
  }
  ${PRINTER_FIELDS}
`

// A waiting print job: a Waiting row, and its copies when it is a batch
export const PRINT_JOB_FIELDS = gql`
  fragment QueuePrintJobFields on PrintJob {
    id
    copies
    position
    held
    samePrinter
    copiesLeftToStart
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
    prints { id copyNumber status progress result printer { id name } }
  }
`

// The /queue page: one field per section, in one request. PRINT_FIELDS brings DashboardPrinterFields.
export const GLOBAL_QUEUE_PAGE = gql`
  query GlobalQueuePage($finished: Int!) {
    globalQueue {
      dispatchPaused
      printersToClear { ...DashboardPrinterFields }
      availablePrinters {
        ...DashboardPrinterFields
        loadedFilaments { slot material colour }
      }
      printing { ...QueuePrintFields }
      waiting { ...QueuePrintJobFields }
      finished(first: $finished) { ...QueuePrintFields }
    }
  }
  ${PRINT_FIELDS}
  ${PRINT_JOB_FIELDS}
`

// Fleet level: something in the queue changed. The payload is small on purpose: the page refetches globalQueue.
export const QUEUE_CHANGED = gql`
  subscription GlobalQueueChanged {
    queueChanged { dispatchPaused }
  }
`
