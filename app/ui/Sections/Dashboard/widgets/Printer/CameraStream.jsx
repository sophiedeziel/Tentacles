import React, { useRef } from 'react'
import PropTypes from 'prop-types'

import useStreamWhenVisible from '../../utils/useStreamWhenVisible'

const FILL = { position: 'absolute', inset: 0, width: '100%', height: '100%' }

// A printer's MJPEG stream, mounted only while its tile is in the viewport and the tab is visible: unmounting the
// <img> closes the connection to the printer (clearing `src` isn't enough in every browser). The dark camera box
// shows through until the first frame.
export default function CameraStream ({ url, name, onError }) {
  const ref = useRef(null)
  const streaming = useStreamWhenVisible(ref)

  return (
    <div ref={ref} style={FILL}>
      {streaming && (
        <img src={url} alt={`${name} webcam`} onError={onError} referrerPolicy="no-referrer"
          style={{ ...FILL, objectFit: 'cover' }} />
      )}
    </div>
  )
}

CameraStream.propTypes = {
  url: PropTypes.string.isRequired,
  name: PropTypes.string.isRequired,
  onError: PropTypes.func.isRequired
}
