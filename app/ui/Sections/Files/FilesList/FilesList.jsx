import React, {useState} from "react";

import { useQuery, useMutation } from '@apollo/client'
import Printfiles from './graphql/Printfiles.graphql'
import UploadFile from './graphql/UploadFile.graphql'

import {Table, Upload, Statistic, Spin} from 'antd'
import { InboxOutlined } from '@ant-design/icons';

const { Dragger } = Upload;

export default function PrintersList() {
  
  const [uploadFile] = useMutation(UploadFile, {
    context: { hasUpload: true },
    update: (cache, {data}) => {
      
      const filesdata = cache.readQuery({ query: Printfiles });

      cache.writeQuery({
        query: Printfiles,
        data: {
          printfiles: [...filesdata.printfiles, data.uploadFile.printfile],
        },
      });
    },
  });
  
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
      sorter: (a, b) => a.filename.localeCompare(b.filename),
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
    {
      title: 'Uploaded at',
      dataIndex: 'createdAt',
      defaultSortOrder: 'descend',
      sorter: (a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt),
    },
  ];

  const onChange = (pagination, filters, sorter, extra) => {
    console.log('params', pagination, filters, sorter, extra);
  }

  const expandedRow = (record) => {
    return(<p style={{ margin: 0 }}>{record.notes}</p>)
  }

  const props = {
    name: 'upload',
    multiple: true,
    showUploadList: false,
    customRequest({file, onProgress, onSuccess}) {
      const variables = {
        fileAttributes: {
          file: file,
          notes: "Some notes"
        }
      }
      uploadFile({variables: {input: variables}});
      onProgress({percent: 100}, file);
      onSuccess(file);
    },
    accept: '.gcode, .stl',
    progress: {
      strokeColor: {
        '0%': '#108ee9',
        '100%': '#87d068',
      },
      strokeWidth: 10,
      format: percent => `${parseFloat(percent.toFixed(2))}%`,
    },
  };

  console.log(printfiles);

  return (
    <>
      <Dragger {...props}>
        <p className="ant-upload-drag-icon">
          <InboxOutlined />
        </p>
        <p className="ant-upload-text">Click or drag file to this area to upload</p>
        <p className="ant-upload-hint">
          Support for a single or bulk upload. Upload your awesomest gcode or stl files.
        </p>
      </Dragger>
      <br />
      <Statistic title="Number of files" value={ printfiles.length } formatter={(value) => (value || <Spin/>)}/>
      <Table 
      rowKey={'id'}
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