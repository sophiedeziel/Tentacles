import React from 'react'
import PropTypes from 'prop-types'
import { Collapse } from 'antd'

function GCodeAnalysis ({ gcodeAnalysis, onLineSelect }) {
  const items = [
    {
      key: '1',
      label: 'Hotend Temperatures',
      children:
      gcodeAnalysis.hotendTemperatures.map((temp) => (
        <pre onClick={() => { onLineSelect(temp.lineNumber) }} key={temp.lineNumber}>Line {temp.lineNumber}: {temp.temperature}</pre>
      ))

    },
    {
      key: '2',
      label: 'Bed Temperatures',
      children: <p></p>
    },
    {
      key: '3',
      label: 'Slicer',
      children: <p>{ gcodeAnalysis.slicer }</p>
    }
  ]

  return (
    <Collapse defaultActiveKey={['3']} items={items} />
  )
}

GCodeAnalysis.propTypes = {
  gcodeAnalysis: PropTypes.object.isRequired,
  onLineSelect: PropTypes.func.isRequired
}

export default GCodeAnalysis
