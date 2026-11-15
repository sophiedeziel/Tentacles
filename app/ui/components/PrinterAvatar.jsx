import React from 'react'
import PropTypes from 'prop-types'

import { Avatar } from 'antd'
import { PrinterOutlined } from '@ant-design/icons'

// OctoPrint printers show the icon their server serves. The others get a generic printer icon.
export default function PrinterAvatar ({ printer }) {
  if (printer.backend === 'OCTOPRINT' && printer.uri) {
    return <Avatar src={`${printer.uri.replace(/\/+$/, '')}/static/img/apple-touch-icon-114x114.png`} />
  }

  return <Avatar icon={<PrinterOutlined />} />
}

PrinterAvatar.propTypes = {
  printer: PropTypes.shape({
    backend: PropTypes.string.isRequired,
    uri: PropTypes.string
  }).isRequired
}
