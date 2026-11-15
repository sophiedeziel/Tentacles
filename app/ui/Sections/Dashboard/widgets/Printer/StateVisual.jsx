import React from 'react'
import PropTypes from 'prop-types'
import { Progress, Spin } from 'antd'

import PrinterStatus from '../../../../components/PrinterStatus/PrinterStatus'
import * as classes from './PrinterWidget.module.less'

// The progress ring while a job is under way, a spinner while connecting, the state icon otherwise
export default function StateVisual ({ view, background }) {
  if (view.ring) {
    return <Progress type="circle" percent={view.progress} size={view.ringSize} strokeColor={view.color} />
  }
  if (view.spin) return <Spin size={view.ringSize > 64 ? 'large' : 'default'} />
  return (
    <span className={classes.stateCircle} style={{
      width: view.iconCircle, height: view.iconCircle, fontSize: view.iconFont, background: background || view.tint
    }}>
      <PrinterStatus family={view.family} text={view.stateText} variant="icon" />
    </span>
  )
}

StateVisual.propTypes = {
  view: PropTypes.object.isRequired,
  background: PropTypes.string
}
