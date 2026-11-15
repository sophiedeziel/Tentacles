import React from 'react'
import PropTypes from 'prop-types'

import PrinterWidget from './PrinterWidget'

// A Printer widget of the layout: picks its printer out of the dashboard's data
export default function PrinterTile ({ widget, size, data }) {
  const printer = data.printersById[widget.printer?.id]
  if (!printer) return null

  return <PrinterWidget printer={printer} size={size} options={widget.options} now={data.now} />
}

PrinterTile.propTypes = {
  widget: PropTypes.shape({ printer: PropTypes.shape({ id: PropTypes.string }), options: PropTypes.object }).isRequired,
  size: PropTypes.string.isRequired,
  data: PropTypes.shape({
    printersById: PropTypes.object.isRequired, now: PropTypes.number.isRequired, live: PropTypes.bool
  }).isRequired
}
