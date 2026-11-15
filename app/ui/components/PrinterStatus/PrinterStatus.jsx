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

const ICONS = {
  PRINTING: Printer3DOutlined,
  PAUSED: PauseCircleOutlined,
  CANCELLING: StopOutlined,
  OPERATIONAL: CheckCircleOutlined,
  CONNECTING: (props) => <SyncOutlined spin {...props} />,
  ERROR: DisconnectOutlined,
  OFFLINE: DisconnectOutlined
}

// A printer's state: its family picks the colour and icon, `text` (OctoPrint's state text) is the label.
// - tag: a filled Tag with the icon, under or beside a printer's name
// - badge: a coloured dot and the label, for small tiles
// - icon: the icon alone, in the family's colour (size it with the parent's font-size)
export default function PrinterStatus ({ family, text, variant = 'tag' }) {
  const palette = statePalette(family)
  const StateIcon = ICONS[family] || ICONS.OFFLINE

  if (variant === 'badge') return <Badge color={palette.color} text={text} />
  if (variant === 'icon') {
    return <span title={text} style={{ color: palette.color, display: 'inline-flex' }}><StateIcon /></span>
  }
  return (
    <Tag variant="filled" color={palette.tag} icon={<StateIcon />} style={{ marginInlineEnd: 0 }}>
      {text}
    </Tag>
  )
}

PrinterStatus.propTypes = {
  family: PropTypes.oneOf(STATE_FAMILIES).isRequired,
  text: PropTypes.string.isRequired,
  variant: PropTypes.oneOf(['tag', 'badge', 'icon'])
}
