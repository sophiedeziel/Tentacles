import React from 'react'
import PropTypes from 'prop-types'
import { Statistic } from 'antd'

import { NEEDS_ATTENTION_FAMILIES, STATE_FAMILIES, STATE_PALETTE } from '../../Foundation/theme'
import * as classes from './FleetSummary.module.less'

// Each figure: its label, the state families it adds up and the colour of its bar
const FIGURES = [
  { label: 'Printing', families: ['PRINTING'], color: STATE_PALETTE.PRINTING.color },
  { label: 'Ready', families: ['OPERATIONAL'], color: STATE_PALETTE.OPERATIONAL.color },
  { label: 'Paused', families: ['PAUSED'], color: STATE_PALETTE.PAUSED.color },
  { label: 'Needs Attention', families: NEEDS_ATTENTION_FAMILIES, color: STATE_PALETTE.ERROR.color }
]

function countFamilies (printers) {
  const counts = {}
  printers.forEach(({ status }) => {
    const family = status?.stateFamily || 'OFFLINE'
    counts[family] = (counts[family] || 0) + 1
  })
  return counts
}

// How the fleet is doing: printers printing, ready, paused and needing attention, each over a bar in its state
// colour. Pass the printers (counted by `status.stateFamily`; no status counts as OFFLINE) or the `counts` per state
// family. CONNECTING printers are in none of the four.
export default function FleetSummary ({ printers = [], counts }) {
  const perFamily = counts || countFamilies(printers)

  return (
    <div className={classes.summary}>
      {FIGURES.map(({ label, families, color }) => (
        <div key={label} className={classes.figure}>
          <span className={classes.bar} style={{ background: color }} />
          <Statistic title={label} value={families.reduce((sum, family) => sum + (perFamily[family] || 0), 0)} />
        </div>
      ))}
    </div>
  )
}

FleetSummary.propTypes = {
  printers: PropTypes.arrayOf(PropTypes.shape({
    status: PropTypes.shape({ stateFamily: PropTypes.oneOf(STATE_FAMILIES) })
  })),
  counts: PropTypes.objectOf(PropTypes.number)
}
