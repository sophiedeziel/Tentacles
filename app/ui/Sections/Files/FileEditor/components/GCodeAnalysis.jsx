import React, { useState, useEffect } from 'react'
import PropTypes from 'prop-types'
import { Collapse, Table, Badge } from 'antd'

function GCodeAnalysis ({ gcodeAnalysis, onLineSelect }) {
  const [openedCollapse, setOpenedCollapse] = useState([])

  useEffect(() => {
    const openedCollapse = JSON.parse(localStorage.getItem('GCodeAnalysis.openedCollapse'))
    if (openedCollapse) {
      setOpenedCollapse(openedCollapse)
    }
  }, [])

  useEffect(() => {
    localStorage.setItem('GCodeAnalysis.openedCollapse', JSON.stringify(openedCollapse))
  }, [openedCollapse])

  const layersTable = () => (
    <Table
    size="small"
    rowKey="lineNumber"
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
    rowKey="lineNumber"
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
    rowKey="lineNumber"
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
      key: 'slicer',
      label: 'Slicer',
      children: <p>{ gcodeAnalysis.slicer }</p>
    },
    {
      key: 'hotendTemperatures',
      label: 'Hotend Temperature changes',
      children: hotendTemperaturesTable(),
      extra: <Badge count={gcodeAnalysis.hotendTemperatures.length} overflowCount={9999} color="purple" />
    },
    {
      key: 'bedTemperatures',
      label: 'Bed Temperature changes',
      children: bedTemperaturesTable(),
      extra: <Badge count={gcodeAnalysis.bedTemperatures.length} overflowCount={9999} color="purple" />
    },
    {
      key: 'layers',
      label: 'Layers',
      children: layersTable(),
      extra: <Badge count={gcodeAnalysis.layers.length} overflowCount={9999} color="purple" />
    }
  ]

  return (
    <Collapse defaultActiveKey={['slicer']} activeKey={openedCollapse} items={items} size="small" onChange={setOpenedCollapse} />
  )
}

GCodeAnalysis.propTypes = {
  gcodeAnalysis: PropTypes.object.isRequired,
  onLineSelect: PropTypes.func.isRequired
}

export default GCodeAnalysis
