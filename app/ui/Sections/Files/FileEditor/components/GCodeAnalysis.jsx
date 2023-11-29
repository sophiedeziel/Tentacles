import React from 'react'
import PropTypes from 'prop-types'
import { Collapse, Table, Badge } from 'antd'

function GCodeAnalysis ({ gcodeAnalysis, onLineSelect }) {
  const layersTable = () => (
    <Table
    size="small"
    columns={[
      {
        title: 'Layer',
        dataIndex: 'id',
        key: 'id'
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
        key: 'height'
      },
      {
        title: 'Z Height',
        dataIndex: 'z',
        key: 'z'
      }
    ]}
    dataSource={gcodeAnalysis.layers}
  />
  )

  const bedTemperaturesTable = () => (
    <Table
    size="small"
    columns={[
      {
        title: 'Line',
        dataIndex: 'lineNumber',
        key: 'lineNumber',
        render: (lineNumber) => (
          <pre onClick={() => { onLineSelect(lineNumber) }}><a>{lineNumber}</a></pre>
        )
      },
      {
        title: 'Temperature',
        dataIndex: 'temperature',
        key: 'temperature'
      },
      {
        title: 'Layer',
        dataIndex: 'layerNumber',
        key: 'layerNumber'
      }
    ]}
    dataSource={gcodeAnalysis.bedTemperatures}
  />
  )

  const hotendTemperaturesTable = () => (
    <Table
    size="small"
    columns={[
      {
        title: 'Line',
        dataIndex: 'lineNumber',
        key: 'lineNumber',
        render: (lineNumber) => (
          <pre onClick={() => { onLineSelect(lineNumber) }}><a>{lineNumber}</a></pre>
        )
      },
      {
        title: 'Temperature',
        dataIndex: 'temperature',
        key: 'temperature'
      },
      {
        title: 'Layer',
        dataIndex: 'layerNumber',
        key: 'layerNumber'
      }
    ]}
    dataSource={gcodeAnalysis.hotendTemperatures}
  />
  )

  const items = [
    {
      key: '1',
      label: 'Slicer',
      children: <p>{ gcodeAnalysis.slicer }</p>
    },
    {
      key: '2',
      label: 'Hotend Temperature changes',
      children: hotendTemperaturesTable(),
      extra: <Badge count={gcodeAnalysis.hotendTemperatures.length} overflowCount={9999} color="purple" />
    },
    {
      key: '3',
      label: 'Bed Temperature changes',
      children: bedTemperaturesTable(),
      extra: <Badge count={gcodeAnalysis.bedTemperatures.length} overflowCount={9999} color="purple" />
    },
    {
      key: '4',
      label: 'Layers',
      children: layersTable(),
      extra: <Badge count={gcodeAnalysis.layers.length} overflowCount={9999} color="purple" />
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
