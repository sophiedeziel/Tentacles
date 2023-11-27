import React from 'react'
import PropTypes from 'prop-types'
import { Collapse, Table } from 'antd'

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
    }, {
      key: '4',
      label: 'Layers',
      children:
      <Table
        size="small"
        columns={[
          {
            title: 'Layer',
            dataIndex: 'id',
            key: 'id',
          },
          {
            title: 'Line',
            dataIndex: 'lineNumber',
            key: 'lineNumber',
            render: (lineNumber) => (
              <pre onClick={() => { onLineSelect(lineNumber) }}><a>{lineNumber}</a></pre>
            )
          },
          {
            title: 'Height',
            dataIndex: 'height',
            key: 'height',
          },
          {
            title: 'Z Height',
            dataIndex: 'z',
            key: 'z',
          }
        ]}
        dataSource={gcodeAnalysis.layers}
      />
      // gcodeAnalysis.layers.map((layer) => (
      //   <pre onClick={() => { onLineSelect(layer.lineNumber) }} key={layer.id}> {layer.id} Line {layer.lineNumber}: layer height: {layer.height} height: {layer.zHeight}</pre>
      // ))
    }
  ]

  return (
    <Collapse defaultActiveKey={['3']} items={items} size="small" />
  )
}

GCodeAnalysis.propTypes = {
  gcodeAnalysis: PropTypes.object.isRequired,
  onLineSelect: PropTypes.func.isRequired
}

export default GCodeAnalysis
