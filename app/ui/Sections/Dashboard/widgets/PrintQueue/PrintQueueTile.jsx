import React, { useEffect, useRef } from 'react'
import PropTypes from 'prop-types'
import { useApolloClient, useQuery } from '@apollo/client/react'

import { ACTIONS } from '../../graphql/actions'
import { PRINT_QUEUE_WIDGET } from '../../graphql/printQueue'
import useRefetchWhenStale from '../../../../utils/useRefetchWhenStale'
import ControlButton from '../Printer/ControlButton'
import PrintQueueWidget from './PrintQueueWidget'
import { rowsToLoad } from './queueView'

const START_NEXT = { key: 'startNext', label: 'Start Next' }

// Reloads the lists when the dashboard reloads, and on its queueVersion: bumped once per burst of queue changes
function useQueueReloads (refetch, skip, queueVersion) {
  const reload = skip ? noop : refetch
  useRefetchWhenStale(reload)
  // Only a version newer than the one at mount reloads (a widget added after a push loads fresh anyway), not a new
  // refetch function
  const latest = useRef(reload)
  latest.current = reload
  const seen = useRef(queueVersion)
  useEffect(() => {
    if (queueVersion === seen.current) return
    seen.current = queueVersion
    latest.current()
  }, [queueVersion])
}

function noop () {}

// A Print Queue widget of the layout: loads the queue and history rows its size shows (the printers come from the
// dashboard), and wires Start Next to the guarded startNextPrint
export default function PrintQueueTile ({ widget, size, data }) {
  const client = useApolloClient()
  const printerId = widget.printer?.id ?? null
  const rows = rowsToLoad(size, widget.options, !!printerId)
  const skip = rows.queue === 0 && rows.history === 0
  const { data: lists, refetch } = useQuery(PRINT_QUEUE_WIDGET, {
    variables: {
      printerId,
      queueRows: rows.queue,
      historyRows: rows.history,
      withQueue: rows.queue > 0,
      withHistory: rows.history > 0
    },
    skip,
    fetchPolicy: 'cache-and-network'
  })
  useQueueReloads(refetch, skip, data.queueVersion)

  // Sends the job the user confirmed, so the server refuses if another one moved to the front
  const run = async (printer, confirmed) => {
    const { mutation, document } = ACTIONS.startNext
    const { data: result } = await client.mutate({ mutation: document, variables: { printerId: printer.id, ...confirmed } })
    return result[mutation].errors
  }

  return (
    <PrintQueueWidget printers={data.printers} printerId={printerId} size={size} options={widget.options}
      queue={lists?.printQueue ?? null} history={lists?.jobHistory ?? null} now={data.now}
      renderStartNext={(printer) => (
        <ControlButton key={printer.id} action={START_NEXT} size="small" placement="topRight"
          view={{ name: printer.name, nextJobName: printer.nextJob?.executable?.filename }}
          snapshot={() => ACTIONS.startNext.expectations(printer)}
          onRun={(_key, confirmed) => run(printer, confirmed)} live={data.live !== false} />
      )} />
  )
}

PrintQueueTile.propTypes = {
  widget: PropTypes.shape({ printer: PropTypes.shape({ id: PropTypes.string }), options: PropTypes.object }).isRequired,
  size: PropTypes.string.isRequired,
  data: PropTypes.shape({
    printers: PropTypes.array.isRequired,
    now: PropTypes.number.isRequired,
    live: PropTypes.bool,
    queueVersion: PropTypes.number
  }).isRequired
}
