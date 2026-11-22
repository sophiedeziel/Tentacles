import React from 'react'
import PropTypes from 'prop-types'
import { Badge, Tag } from 'antd'
import {
  CheckCircleOutlined,
  DisconnectOutlined,
  PauseCircleOutlined,
  StopOutlined,
  SyncOutlined
} from '@ant-design/icons'

import { Printer3DOutlined } from '../icons'
import { STATE_FAMILIES, statePalette } from '../../Foundation/theme'
import * as classes from './PrinterStatus.module.less'

const ICONS = {
  PRINTING: Printer3DOutlined,
  PAUSED: PauseCircleOutlined,
  CANCELLING: StopOutlined,
  OPERATIONAL: CheckCircleOutlined,
  CONNECTING: SyncOutlined,
  ERROR: DisconnectOutlined,
  OFFLINE: DisconnectOutlined
}

// The working family moves: printing pulses, and the states that settle on their own breathe.
// Pausing and resuming have no family of their own (they read as paused and printing).
const MOTIONS = {
  PRINTING: 'pulse',
  CONNECTING: 'breathe',
  CANCELLING: 'breathe'
}

// A printer's state: its family picks the colour, icon and motion, `text` (OctoPrint's state text) is the label.
// - tag: a filled Tag with the icon, under or beside a printer's name
// - badge: a coloured dot and the label, for small tiles
// - icon: the icon alone, in the family's colour (size it with the parent's font-size)
export default function PrinterStatus ({ family, text, variant = 'tag' }) {
  const palette = statePalette(family)
  const StateIcon = ICONS[family] || ICONS.OFFLINE
  const motion = MOTIONS[family]
  const motionProps = motion ? { className: classes[motion], 'data-motion': motion } : {}

  if (variant === 'badge') return <Badge color={palette.color} text={text} {...motionProps} />
  if (variant === 'icon') {
    return (
      <span title={text} style={{ color: palette.color, display: 'inline-flex' }} {...motionProps}>
        <StateIcon />
      </span>
    )
  }
  return (
    <Tag variant="filled" color={palette.tag} icon={<StateIcon />} style={{ marginInlineEnd: 0 }} {...motionProps}>
      {text}
    </Tag>
  )
}

PrinterStatus.propTypes = {
  family: PropTypes.oneOf(STATE_FAMILIES).isRequired,
  text: PropTypes.string.isRequired,
  variant: PropTypes.oneOf(['tag', 'badge', 'icon'])
}
