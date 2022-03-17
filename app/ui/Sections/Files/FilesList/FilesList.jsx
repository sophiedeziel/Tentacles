import React from "react";

import { useQuery } from '@apollo/client'
import Printfiles from './graphql/Printfiles.graphql'

import {Empty, Table} from 'antd'

export default function PrintersList() {

  const { loading, error, data: printfilesData } = useQuery(Printfiles);

  if (error) return(<>Error!{error.message}</>);

  if (loading) return(<>Loading</>);

  const {printfiles} = printfilesData;

  const columns = [
    Table.SELECTION_COLUMN,
    {
      title: 'Name',
      dataIndex: 'filename',
      defaultSortOrder: 'ascend',
      sorter: (a, b) => a.name.localeCompare(b.name),
    },
    Table.EXPAND_COLUMN,
    {
      title: 'Type',
      dataIndex: 'filetype',
      defaultSortOrder: 'descend',
      sorter: (a, b) => a.type - b.type,
      filters: [
        {
          text: '.gcode',
          value: '.gcode',
        },
        {
          text: '.stl',
          value: '.stl',
        },
      ],
      onFilter: (value, record) => record.type.indexOf(value) === 0,
    },
    // {
    //   title: 'Compatible with',
    //   dataIndex: 'printers',
    //   filters: [
    //     {
    //       text: 'CR10s',
    //       value: '1',
    //     },
    //     {
    //       text: 'Ender 3 V2',
    //       value: '2',
    //     },
    //   ],
    //   onFilter: (value, record) => record.address.indexOf(value) === 0,
    // },
  ];
  
  const data = [
    {
      key: 1,
      name: "Bubasaur.gcode",
      type: ".gcode",
      printers: ['CR10s']
    }
  ];

  const onChange = (pagination, filters, sorter, extra) => {
    console.log('params', pagination, filters, sorter, extra);
  }

  const expandedRow = (record) => {
    return(<p style={{ margin: 0 }}>{record.notes}</p>)
  }

  return (
    <>
      <Table 
      columns={columns} 
      dataSource={printfiles} 
      onChange={onChange} 
      rowSelection={{}}
      expandable={{
        expandedRowRender: expandedRow
      }}
      />
    </>
  );
}