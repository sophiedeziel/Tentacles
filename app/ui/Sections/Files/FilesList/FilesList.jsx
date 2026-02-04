import React, { useState } from 'react'
import { Link } from 'react-router'
import { saveAs } from 'file-saver'

import { useQuery, useMutation } from '@apollo/client/react'

import Files from 'graphql/Files.graphql'
import UploadFile from 'graphql/UploadFile.graphql'
import ArchiveFiles from 'graphql/ArchiveFiles.graphql'
import UnarchiveFiles from 'graphql/UnarchiveFiles.graphql'

import { Table, Upload, Statistic, Spin, Button, Form, Tabs, Space, Dropdown, Tag } from 'antd'
import { InboxOutlined } from '@ant-design/icons'
import LabelApplicator from './components/LabelApplicator'
// import FileDetails from './components/FileDetails/FileDetails'

const filesize = require('file-size')

const { Dragger } = Upload

export default function FilesList () {
  const filters = {
    active: (file) => {
      return (!file.isArchived && !file.isDeleted)
    },
    archived: (file) => { return (file.isArchived && !file.isDeleted) },
    trash: (file) => { return (file.isDeleted) }
  }
  const [selectedRowKeys, setSelectedRowKeys] = useState([])
  const [filesFilters, setFilesFilters] = useState('active')

  const [uploadFile] = useMutation(UploadFile, {
    context: { hasUpload: true },
    update: (cache, { data }) => {
      const filesdata = cache.readQuery({ query: Files })

      cache.writeQuery({
        query: Files,
        data: {
          files: [...filesdata.files, data.uploadFile.file]
        }
      })
    }
  })

  const saveFile = (downloadUrl, filename) => {
    saveAs(
      downloadUrl,
      filename
    )
  }

  const [archiveFiles] = useMutation(ArchiveFiles, {
    update: (cache, { data: _data }) => {
      const filesdata = cache.readQuery({ query: Files })
      setSelectedRowKeys([])

      const filteredFiles = filesdata.files.map((file) => {
        if (selectedRowKeys.indexOf(file.id) !== -1) {
          return { ...file, isArchived: true }
        }
        return file
      })

      cache.writeQuery({
        query: Files,
        data: {
          files: filteredFiles
        }
      })
    }
  })

  const [unarchiveFiles] = useMutation(UnarchiveFiles, {
    update: (cache, { data: _data }) => {
      const filesdata = cache.readQuery({ query: Files })
      setSelectedRowKeys([])

      const filteredFiles = filesdata.files.map((file) => {
        if (selectedRowKeys.indexOf(file.id) !== -1) {
          return { ...file, isArchived: false }
        }
        return file
      })

      cache.writeQuery({
        query: Files,
        data: {
          files: filteredFiles
        }
      })
    }
  })

  const { loading, error, data: filesData } = useQuery(Files)
  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const labels = filesData.labels?.edges

  const files = filesData.files?.filter(filters[filesFilters])

  const columns = [
    Table.SELECTION_COLUMN,
    {
      title: 'Name',
      defaultSortOrder: 'ascend',
      sorter: (a, b) => a.filename.localeCompare(b.filename),
      render: (file) => {
        return (<Link to={'/files/' + file.id }>{file.filename}</Link>)
      }
    },
    {
      title: 'Labels',
      dataIndex: 'labels',
      render: (labels) => {
        return labels.edges.map(({ node }) => {
          return (<Tag key={node.id} color={node.color}>{node.name}</Tag>)
        })
      }
    },
    {
      title: 'Type',
      dataIndex: 'filetype',
      defaultSortOrder: 'descend',
      sorter: (a, b) => a.type - b.type,
      filters: [
        {
          text: '.gcode',
          value: '.gcode'
        },
        {
          text: '.stl',
          value: '.stl'
        }
      ],
      onFilter: (value, record) => record.filetype === value
    },
    {
      title: 'Uploaded at',
      dataIndex: 'createdAt',
      defaultSortOrder: 'descend',
      sorter: (a, b) => Date.parse(a.createdAt) - Date.parse(b.createdAt)
    },
    {
      title: 'File size',
      dataIndex: 'filesize',
      defaultSortOrder: 'descend',
      sorter: (a, b) => a.type - b.type,
      render: (value) => filesize(value).human('si')
    },
    {
      title: 'Action',
      key: 'action',
      sorter: true,
      render: (file) => {
        const items = [
          {
            label: <Link to={'/files/' + file.id}>Edit</Link>,
            key: 'edit'
          },
          {
            label: 'Download',
            key: 'download',
            onClick: () => { saveFile(file.downloadUrl, file.filename) }
          }
        ]

        return (
          <Space size="middle">
            <Dropdown.Button menu={{ items }} >
              <Link to={'/files/' + file.id + '/print'}>Print</Link>
            </Dropdown.Button>
          </Space>
        )
      }
    }
  ]

  const props = {
    height: '200px',
    name: 'upload',
    multiple: true,
    showUploadList: false,
    customRequest ({ file, onProgress, onSuccess }) {
      const variables = {
        fileAttributes: {
          file,
          notes: 'Some notes'
        }
      }
      uploadFile({ variables: { input: variables } })
      onProgress({ percent: 100 }, file)
      onSuccess(file)
    },
    accept: '.gcode, .stl',
    progress: {
      strokeColor: {
        '0%': '#108ee9',
        '100%': '#87d068'
      },
      strokeWidth: 10,
      format: percent => `${parseFloat(percent.toFixed(2))}%`
    }
  }

  const onSelectChange = (newSelectedRowKeys) => {
    setSelectedRowKeys(newSelectedRowKeys)
  }

  const handleArchiveClick = () => {
    archiveFiles({ variables: { input: { fileIds: selectedRowKeys } } })
  }

  const handleUnarchiveClick = () => {
    unarchiveFiles({ variables: { input: { fileIds: selectedRowKeys } } })
  }

  const rowSelection = {
    selectedRowKeys,
    onChange: onSelectChange
  }
  const hasSelected = selectedRowKeys.length > 0

  const handleTabChange = (key) => {
    setFilesFilters(key)
  }

  // const expandedRow = (record) => {
  //   return (
  //     <FileDetails record={record} />
  //   )
  // }

  const items = [
    {
      key: 'active',
      label: 'Active',
      children:
        <Form.Item label={selectedRowKeys.length + ' selected : '}>
          <Space>
          <Button type="primary" onClick={handleArchiveClick} disabled={!hasSelected} loading={loading}>
            Archive
          </Button>
          <LabelApplicator
            disabled={!hasSelected}
            labels={labels}
            files={files}
            selectedRowKeys={selectedRowKeys}
          />
          </Space>
        </Form.Item>
    },
    {
      key: 'archived',
      label: 'Archived',
      children:
        <Form.Item label={selectedRowKeys.length + ' selected : '}>
          <Button type="primary" onClick={handleUnarchiveClick} disabled={!hasSelected} loading={loading}>
            Unarchive
          </Button>
        </Form.Item>
    }
  ]

  return (
    <>
      <Statistic title="Number of files" value={ files.length } formatter={(value) => (value || <Spin/>)}/>
      <Tabs defaultActiveKey="1" onChange={handleTabChange} items={items} />
      <Table
      columns={columns}
      dataSource={files}
      // expandable={{
      //   expandedRowRender: expandedRow
      // }}
      pagination={false}
      rowKey={'id'}
      rowSelection={rowSelection}
      />
      <br />
      <Dragger {...props}>
        <p className="ant-upload-drag-icon">
          <InboxOutlined />
        </p>
        <p className="ant-upload-text">Click or drag file to this area to upload</p>
        <p className="ant-upload-hint">
          Support for a single or bulk upload. Upload your awesomest gcode or stl files.
        </p>
      </Dragger>
    </>
  )
}
