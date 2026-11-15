import React from 'react'
import PropTypes from 'prop-types'
import { Card } from 'antd'

import * as classes from './WidgetFrame.module.less'

const STYLES = {
  root: { height: '100%' },
  body: { height: '100%', padding: 12, display: 'flex', flexDirection: 'column', boxSizing: 'border-box' }
}

// The card every widget sits in. In edit mode the widget can't be used, only arranged: its content is inert.
export default function WidgetFrame ({ children, label, editing = false }) {
  const card = <Card size="small" styles={STYLES} aria-label={label}>{children}</Card>
  if (!editing) return card

  return (
    <div className={classes.editing}>
      <div className={classes.content} inert>{card}</div>
    </div>
  )
}

WidgetFrame.propTypes = {
  children: PropTypes.node,
  label: PropTypes.string,
  editing: PropTypes.bool
}
