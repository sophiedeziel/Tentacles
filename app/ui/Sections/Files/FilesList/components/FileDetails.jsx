import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { Button, Form, Row, Col, Input, Card, Space } from 'antd'
import ReactMarkdown from 'react-markdown'

import UpdateFileNotes from '../../graphql/UpdateFileNotes.graphql'
import Files from '../../graphql/Files.graphql'

import { useMutation } from '@apollo/client/react'
import { EditOutlined } from '@ant-design/icons'

const { TextArea } = Input

function FileDetails ({ record }) {
  const [updateFileNotes] = useMutation(UpdateFileNotes, {
    update: (cache, { data }) => {
      const filesdata = cache.readQuery({ query: Files })

      const filteredFiles = filesdata.files.map((file) => {
        if (file.id === data.updateFileNotes.file.id) {
          return data.updateFileNotes.file
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

  const [editMode, setEditMode] = useState(false)

  const onNotesSave = (values) => {
    updateFileNotes({ variables: { input: { id: values.id, notes: values.notes } } })
    toggleEdit()
  }

  const toggleEdit = () => {
    setEditMode(!editMode)
  }

  return (
    <Row>
      <Col span={12}>
        <pre style={{ margin: 0 }}>{record.topFileComments}</pre>
      </Col>
      <Col span={12}>
        { editMode === true
          ? <Form
          name={'FileNotesForm'}
          onFinish={onNotesSave}
          autoComplete="off"
          initialValues={{ notes: record.notes, id: record.id }}
          >
          <Form.Item hidden name="id" >
            <Input />
          </Form.Item>
          <Form.Item name="notes">
            <TextArea rows={10} />
          </Form.Item>
          <Form.Item>
            <Space>
              <Button type="primary" htmlType="submit">
                Save
              </Button>
              <Button onClick={toggleEdit}>Cancel</Button>
            </Space>
          </Form.Item>
        </Form>
          : <Card title="Notes" extra={<EditOutlined onClick={toggleEdit}/>}>
          <ReactMarkdown>
            {record.notes}
          </ReactMarkdown>
          </Card>
        }
      </Col>
    </Row>
  )
}

FileDetails.propTypes = {
  record: PropTypes.object.isRequired
}

export default FileDetails
