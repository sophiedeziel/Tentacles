import React from 'react'
import PropTypes from 'prop-types'

import { Avatar } from 'antd'

import { Printer3DOutlined } from '../icons'
import * as classes from './PrinterAvatar.module.less'

// OctoPrint printers show the icon their server serves. The others, and an OctoPrint server that can't be reached, get
// the 3D printer icon on the same tile as the fleet list's. Decorative: the printer's name sits next to it.
export default function PrinterAvatar ({ printer }) {
  const src = printer.backend === 'OCTOPRINT' && printer.uri
    ? `${printer.uri.replace(/\/+$/, '')}/static/img/apple-touch-icon-114x114.png`
    : undefined

  return (
    <Avatar shape="square" size={40} className={classes.avatar} src={src} alt=""
      icon={<Printer3DOutlined aria-hidden />} />
  )
}

PrinterAvatar.propTypes = {
  printer: PropTypes.shape({
    backend: PropTypes.string.isRequired,
    uri: PropTypes.string
  }).isRequired
}
