import React, { useEffect, useState } from 'react'
import PropTypes from 'prop-types'
import { useApolloClient } from '@apollo/client/react'

import { ACTIONS } from '../../graphql/actions'
import CameraStream from './CameraStream'
import ControlButton from './ControlButton'
import PrinterWidget from './PrinterWidget'

const STREAM_RETRY_DELAY = 30000

// A Printer widget of the layout: picks its printer out of the dashboard's data, streams its camera while it is
// visible and wires its controls to the printer mutations
export default function PrinterTile ({ widget, size, data }) {
  const client = useApolloClient()
  const printer = data.printersById[widget.printer?.id]
  const streamUrl = printer?.status.camera.streamUrl
  const family = printer?.status.stateFamily
  const [streamFailed, setStreamFailed] = useState(false)

  // A new stream URL or state gets a new try, and so does a failed stream after a while (a restarted webcam)
  useEffect(() => setStreamFailed(false), [streamUrl, family])
  useEffect(() => {
    if (!streamFailed) return undefined
    const timer = setTimeout(() => setStreamFailed(false), STREAM_RETRY_DELAY)
    return () => clearTimeout(timer)
  }, [streamFailed])

  if (!printer) return null

  // Sends what the user confirmed (the file printing, the next job), so the server refuses if the printer moved on
  const run = async (key, confirmed) => {
    const { mutation, document } = ACTIONS[key]
    const { data: result } = await client.mutate({ mutation: document, variables: { printerId: printer.id, ...confirmed } })
    return result[mutation].errors
  }

  return (
    <PrinterWidget printer={printer} size={size} options={widget.options} now={data.now} streamFailed={streamFailed}
      cameraStream={streamUrl && <CameraStream url={streamUrl} name={printer.name} onError={() => setStreamFailed(true)} />}
      renderAction={(action, view) => (
        <ControlButton key={action.key} action={action} view={view} onRun={run} live={data.live !== false}
          snapshot={() => ACTIONS[action.key]?.expectations?.(printer)} />
      )} />
  )
}

PrinterTile.propTypes = {
  widget: PropTypes.shape({ printer: PropTypes.shape({ id: PropTypes.string }), options: PropTypes.object }).isRequired,
  size: PropTypes.string.isRequired,
  data: PropTypes.shape({
    printersById: PropTypes.object.isRequired, now: PropTypes.number.isRequired, live: PropTypes.bool
  }).isRequired
}
