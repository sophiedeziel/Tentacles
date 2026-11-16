import React from 'react'
import PropTypes from 'prop-types'
import { Progress } from 'antd'

import { STATE_FAMILIES, statePalette } from '../../Foundation/theme'
import { formatTimeLeft } from '../../utils/time'
import * as classes from './PrintProgress.module.less'

// The line under the bar: time left while printing (or the percentage when the printer doesn't say), where the
// print stopped when paused or cancelling, nothing otherwise
function progressText (family, percent, timeLeft) {
  if (family === 'PRINTING') return timeLeft == null ? `${percent}% printed` : `${formatTimeLeft(timeLeft)} left`
  if (family === 'PAUSED') return `Paused at ${percent}%`
  if (family === 'CANCELLING') return `Stopping at ${percent}%`
  return null
}

// A job's progress bar, in its printer's state colour, and a line saying how it goes.
// `timeLeft` is in milliseconds: the caller works it out from the status and its clock (see doneAt in utils/time).
export default function PrintProgress ({ family, progress, timeLeft = null }) {
  const percent = Math.round(progress ?? 0)
  const text = progressText(family, percent, timeLeft)

  return (
    <div className={classes.progress}>
      <Progress percent={percent} strokeColor={statePalette(family).color} status="normal" />
      {text && <span className={classes.text}>{text}</span>}
    </div>
  )
}

PrintProgress.propTypes = {
  family: PropTypes.oneOf(STATE_FAMILIES).isRequired,
  progress: PropTypes.number,
  timeLeft: PropTypes.number
}
