import { gql } from '@apollo/client'

// A Print Queue widget's lists, cut to the rows its size shows. Each list is left out when the size shows none.
export const PRINT_QUEUE_WIDGET = gql`
  query DashboardPrintQueue(
    $printerId: ID, $queueRows: Int!, $historyRows: Int!, $withQueue: Boolean!, $withHistory: Boolean!
  ) {
    printQueue(printerId: $printerId, first: $queueRows) @include(if: $withQueue) {
      totalCount
      jobs { id executable { id filename } printer { id name } }
    }
    jobHistory(printerId: $printerId, first: $historyRows) @include(if: $withHistory) {
      id status updatedAt executable { id filename } printer { id name }
    }
  }
`
