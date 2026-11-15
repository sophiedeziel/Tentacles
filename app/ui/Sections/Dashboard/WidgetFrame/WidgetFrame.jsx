import React from 'react'
import PropTypes from 'prop-types'
import { Card } from 'antd'

const STYLES = {
  root: { height: '100%' },
  body: { height: '100%', padding: 12, display: 'flex', flexDirection: 'column', boxSizing: 'border-box' }
}

// The card every widget sits in. Edit mode adds its toolbar (size, move, settings, remove) here.
export default function WidgetFrame ({ children, label }) {
  return <Card size="small" styles={STYLES} aria-label={label}>{children}</Card>
}

WidgetFrame.propTypes = {
  children: PropTypes.node,
  label: PropTypes.string
}
