import React from 'react'
import PropTypes from 'prop-types'
import { useNavigate } from 'react-router'
import { Button } from 'antd'

import { PrintQueueOutlined } from '../../../components/icons'
import useQueueEnabled from '../useQueueEnabled'

// Whether the queue can print a file: G-code only (a model has to be sliced first), as the file picker lists them
export const queueable = (file) => file?.filetype?.toLowerCase() === '.gcode'

// The file page's way into the queue: opens Add to Queue for a G-code file while the global queue is on, renders
// nothing otherwise
export default function AddToQueueButton ({ file }) {
  const navigate = useNavigate()
  const queue = useQueueEnabled()
  if (!queue.enabled || !queueable(file)) return null

  return (
    <Button type="primary" icon={<PrintQueueOutlined aria-hidden />} onClick={() => navigate(`/queue/add/${file.id}`)}>
      Add to Queue
    </Button>
  )
}

AddToQueueButton.propTypes = {
  file: PropTypes.shape({
    id: PropTypes.string.isRequired,
    filetype: PropTypes.string
  }).isRequired
}
