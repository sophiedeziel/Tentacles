import { gql } from '@apollo/client'

// The summary has no id: Apollo keeps it inside its File, so every document that selects it selects all of it
import GCODE_SUMMARY_FIELDS from 'graphql/GcodeSummaryFragment.graphql'

// The file the form adds, with what its G-code says (null for a file that isn't G-code, PENDING until it is read), and
// the lists the Material and Colour fields pick from
export const ADD_TO_QUEUE_FILE = gql`
  query AddToQueueFile($fileId: ID!) {
    file(id: $fileId) {
      id
      filename
      filesize
      notes
      isDeleted
      gcodeSummary { ...GcodeSummaryFields }
    }
    filamentMaterials
    filamentColours
  }
  ${GCODE_SUMMARY_FIELDS}
`

// The Printers card: how every printer fits the file with the filament asked for. Its state and loaded filament are
// read here too (no live updates: the fits are recomputed when the filament changes, and on Refresh).
export const PRINTER_FITS = gql`
  query AddToQueuePrinterFits($fileId: ID!, $material: String, $colour: String) {
    printerFits(fileId: $fileId, material: $material, colour: $colour) {
      result
      hardLimit
      reasons { code message }
      printer {
        id
        name
        filamentSlots
        status { stateFamily stateText }
        loadedFilaments { slot material colour }
      }
    }
  }
`

// The Summary card: the queue now, the totals and what happens to the job first, for the options of the form
export const QUEUE_ESTIMATE = gql`
  query AddToQueueEstimate(
    $fileId: ID!, $copies: Int, $material: String, $colour: String, $samePrinter: Boolean, $printerIds: [ID!],
    $position: MovePrintJobTo, $held: Boolean, $printJobId: ID
  ) {
    queueEstimate(
      fileId: $fileId, copies: $copies, material: $material, colour: $colour, samePrinter: $samePrinter,
      printerIds: $printerIds, position: $position, held: $held, printJobId: $printJobId
    ) {
      printing
      waitingJobs
      jobsAhead
      printsAhead
      copiesToPrint
      filaments { tool material colour grams metres }
      filamentGrams
      filamentMetres
      printSeconds
      starts { kind printer { id name } jobsAhead dispatchPaused startsAt }
    }
  }
`

// Saves the form. printerIds left out: every printer that can print it (all_capable), printers added later included.
export const ADD_PRINT_JOB = gql`
  mutation AddToQueueSave(
    $fileId: ID!, $copies: Int, $material: String, $colour: String, $samePrinter: Boolean, $printerIds: [ID!],
    $position: MovePrintJobTo, $held: Boolean
  ) {
    addToQueue(input: {
      fileId: $fileId, copies: $copies, material: $material, colour: $colour, samePrinter: $samePrinter,
      printerIds: $printerIds, position: $position, held: $held
    }) {
      success
      errors { field message }
      printJob { id }
    }
  }
`
