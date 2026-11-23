import React from 'react'
import PropTypes from 'prop-types'
import { Tag } from 'antd'
import { CheckCircleOutlined, ClockCircleOutlined, CloseCircleOutlined, StopOutlined } from '@ant-design/icons'

import { Printer3DOutlined } from '../icons'
import { STATE_PALETTE } from '../../Foundation/theme'

// A job's status, in the printer state palette: printing reads like a printing printer, completed like a ready one,
// failed like one in error, and enqueued (waiting its turn) and cancelled in the neutral grey of an offline one
const STATUSES = {
  enqueued: { label: 'Enqueued', palette: STATE_PALETTE.OFFLINE, Icon: ClockCircleOutlined },
  active: { label: 'Printing', palette: STATE_PALETTE.PRINTING, Icon: Printer3DOutlined },
  completed: { label: 'Completed', palette: STATE_PALETTE.OPERATIONAL, Icon: CheckCircleOutlined },
  error: { label: 'Failed', palette: STATE_PALETTE.ERROR, Icon: CloseCircleOutlined },
  failed: { label: 'Failed', palette: STATE_PALETTE.ERROR, Icon: CloseCircleOutlined },
  cancelled: { label: 'Cancelled', palette: STATE_PALETTE.OFFLINE, Icon: StopOutlined }
}

// A job's status as a filled Tag, like PrinterStatus. The status comes as stored, so a status added later reads as
// itself, in grey and without an icon.
export default function JobStatus ({ status }) {
  const known = STATUSES[status]
  const label = known ? known.label : status.charAt(0).toUpperCase() + status.slice(1)
  const { tag } = known ? known.palette : STATE_PALETTE.OFFLINE

  return (
    <Tag variant="filled" color={tag} icon={known && <known.Icon />} style={{ marginInlineEnd: 0 }}>
      {label}
    </Tag>
  )
}

JobStatus.propTypes = {
  status: PropTypes.string.isRequired
}
