import React, {useState} from "react";

import { useQuery, useMutation } from '@apollo/client'
import Files from './graphql/Files.graphql'
import UploadFile from './graphql/UploadFile.graphql'

import {Table, Upload, Statistic, Spin, Button, Form} from 'antd'
import { InboxOutlined } from '@ant-design/icons';

var filesize = require('file-size');

const { Dragger } = Upload;

export default function PrintersList() {
  const [selectedRowKeys, setSelectedRowKeys] = useState([]);
  const [uploadFile] = useMutation(UploadFile, {
    context: { hasUpload: true },
    update: (cache, {data}) => {
      
      const filesdata = cache.readQuery({ query: Files });

      cache.writeQuery({
        query: Files,
        data: {
          files: [...filesdata.files, data.uploadFile.printfile],
        },
      });
    },
  });
  
  const { loading, error, data: filesData } = useQuery(Files);
  if (error) return(<>Error!{error.message}</>);

  if (loading) return(<>Loading</>);

  const {files} = filesData;

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
    {
      title: 'File size',
      dataIndex: 'filesize',
      defaultSortOrder: 'descend',
      sorter: (a, b) => a.type - b.type,
      render: (value) => filesize(value).human('si'),
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

  const onSelectChange = (selectedRowKeys) => {
    console.log('selectedRowKeys changed: ', selectedRowKeys);
    setSelectedRowKeys(selectedRowKeys);
  };

  const rowSelection = {
    selectedRowKeys,
    onChange: onSelectChange,
  };
  const hasSelected = selectedRowKeys.length > 0;

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
      <Statistic title="Number of files" value={ files.length } formatter={(value) => (value || <Spin/>)}/>
      <div style={{ marginBottom: 16 }}>
        <Form.Item label={selectedRowKeys.length + " selected : "}>
          
          <Button type="primary"  disabled={!hasSelected} loading={loading}>
            Archive
          </Button>
        </Form.Item>
      </div>
      <Table 
      rowKey={'id'}
      columns={columns} 
      dataSource={files} 
      onChange={onChange} 
      rowSelection={rowSelection}
      expandable={{
        expandedRowRender: expandedRow
      }}
      />
    </>
  );
}