import { gql } from '@apollo/client'

// Shared with UpdateFile.graphql, whose returned file carries the summary a save resets to PENDING
import GCODE_SUMMARY_FIELDS from 'graphql/GcodeSummaryFragment.graphql'

export { GCODE_SUMMARY_FIELDS }

// The print details read from one file's G-code; null for a file that isn't G-code
export const GCODE_SUMMARY = gql`
  query GcodeSummary($fileId: ID!) {
    file(id: $fileId) {
      id
      gcodeSummary { ...GcodeSummaryFields }
    }
  }
  ${GCODE_SUMMARY_FIELDS}
`

// Resets the summary to PENDING and reads the file again
export const REANALYSE_GCODE = gql`
  mutation ReanalyseGcode($input: ReanalyseGcodeInput!) {
    reanalyseGcode(input: $input) {
      file {
        id
        gcodeSummary { ...GcodeSummaryFields }
      }
      errors { field message }
    }
  }
  ${GCODE_SUMMARY_FIELDS}
`
