// import React, { useState } from 'react'
import React from 'react'
// import { arrayMoveImmutable } from 'array-move'
// import { SortableContainer, SortableElement, SortableHandle } from 'react-sortable-hoc'

import { Table } from 'antd'
// import { MenuOutlined } from '@ant-design/icons'

// import classes from './PrintTable.module.less'

// const DragHandle = SortableHandle(() => (
//   <MenuOutlined
//     style={{
//       cursor: 'grab',
//       color: '#999'
//     }}
//   />
// ))

const columns = [
  // {
  //   title: 'Sort',
  //   dataIndex: 'sort',
  //   width: 30,
  //   className: 'drag-visible',
  //   render: () => <DragHandle />
  // },
  {
    title: 'File',
    dataIndex: 'filename',
    className: 'drag-visible'
  },
  {
    title: 'Status',
    dataIndex: 'status'
  },
  {
    title: 'Enqueued at',
    dataIndex: 'createdAt'
  }
]

// const SortableItem = SortableElement((props) => <tr {...props} />)
// const SortableBody = SortableContainer((props) => <tbody {...props} />)

// eslint-disable-next-line react/prop-types
export default function PrintTable ({ jobs }) {
  // const [dataSource, setDataSource] = useState(jobs)

  // const onSortEnd = ({ oldIndex, newIndex }) => {
  //   if (oldIndex !== newIndex) {
  //     const newData = arrayMoveImmutable(dataSource.slice(), oldIndex, newIndex).filter(
  //       (el) => !!el
  //     )
  //     console.log('Sorted items: ', newData)
  //     setDataSource(newData)
  //   }
  // }

  // const DraggableContainer = (props) => (
  //   <SortableBody
  //     useDragHandle
  //     disableAutoscroll
  //     helperClass={classes.rowDragging}
  //     onSortEnd={onSortEnd}
  //     {...props}
  //   />
  // )

  // const DraggableBodyRow = ({ className, style, ...restProps }) => {
  //   // function findIndex base on Table rowKey props and should always be a right array index
  //   const index = dataSource.findIndex((x) => x.index === restProps['data-row-key'])
  //   return <SortableItem index={index} {...restProps} />
  // }

  return (
    <Table
      pagination={false}
      dataSource={jobs}
      columns={columns}
      rowKey="index"
      // components={{
      //   body: {
      //     wrapper: DraggableContainer,
      //     row: DraggableBodyRow
      //   }
      // }}
    />
  )
}
