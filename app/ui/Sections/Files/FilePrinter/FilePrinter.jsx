import React, { useState } from 'react'
import { useMatch } from 'react-router'
import { useQuery, useMutation } from '@apollo/client/react'
import ReactMarkdown from 'react-markdown'
// import { GCodeViewer } from 'react-gcode-viewer'

import * as classes from './FilePrinter.module.less'

import { Col, Row, Card, Checkbox, Button, List, Statistic, message } from 'antd'
import { PageHeader } from '@ant-design/pro-layout'

import File from './graphql/File.graphql'
import SendFileToPrinters from './graphql/SendFileToPrinters.graphql'
import EnqueueFiles from './graphql/EnqueueFiles.graphql'

export default function FilePrinter () {
  const [selectedPrinters, setSelectedPrinters] = useState([])
  const match = useMatch('/files/:id/print')
  const fileID = match.params.id

  const [sendFileToPrinters] = useMutation(SendFileToPrinters)
  const [enqueueFiles] = useMutation(EnqueueFiles)

  const { loading, error, data: queryData } = useQuery(File, {
    variables: { id: fileID }
  })

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { file, printers } = queryData

  const handleUpload = () => {
    if (selectedPrinters.length === 0) {
      message.error('Please select at least one printer')
      return
    }
    sendFileToPrinters({
      variables: {
        input: {
          fileIds: [fileID],
          printerIds: selectedPrinters
        }
      }
    })
  }

  const handleEnqueue = () => {
    if (selectedPrinters.length === 0) {
      message.error('Please select at least one printer')
      return
    }
    enqueueFiles({
      variables: {
        enqueueFilesInput: {
          fileIds: [fileID],
          printerIds: selectedPrinters
        }
      }
    }).then(() => {
      message.success(`File enqueued on ${selectedPrinters.length} printer${selectedPrinters.length > 1 ? 's' : ''}`)
    })
  }

  const handlePrinterSelectChange = (id, checked) => {
    if (checked) {
      setSelectedPrinters([...selectedPrinters, id])
    } else {
      setSelectedPrinters(selectedPrinters.filter(item => item !== id))
    }
  }

  return (
    <>
      <PageHeader
        className="site-page-header"
        ghost={false}
        onBack={() => window.history.back()}
        title={file.filename}
      >
      </PageHeader>
      <Row className={classes.printersList} gutter={8}>
        <Col span={12}>
          <Card title="Select printers" >
            <List
              itemLayout="horizontal"
              dataSource={printers}
              renderItem={item => (
                <List.Item>
                  <List.Item.Meta
                    avatar={<Checkbox onChange={(e) => { handlePrinterSelectChange(item.id, e.target.checked) } } />}
                    title={item.name}
                    description={item.jobStatus}
                  />
                </List.Item>
              )}
            />
            <Row style={{ marginTop: 12 }}>
              <Button type="primary" onClick={handleEnqueue}>Enqueue print</Button>
              <Button onClick={handleUpload}>Upload</Button>
            </Row>
          </Card>
        </Col>
        <Col span={12}>
          <Card title="File Preview" >
            {/* <GCodeViewer
              orbitControls
              showAxes
              quality={0.2}
              floorProps={{
                gridWidth: 300,
                gridLength: 300
              }}
              style={{
                top: 0,
                left: 0,
                width: '100%',
                height: '400px'
              }}
              url={file.downloadUrl}
            /> */}
          </Card>
          <Card title="File informations" >
            <Row>
              <Statistic title="Estimated print time" value="~3h" />
            </Row>
            <Row gutter={16}>
              <Col span={12}>
                <Statistic title="Filament weight" value="15g" />
              </Col>
              <Col span={12}>
                <Statistic title="Filament length" value="7m" />
              </Col>
            </Row>
            <Row>
              <Statistic title="Model size" value="154.60mm × 162.20mm × 11.00mm" />
            </Row>
          </Card>
          <Card title="Notes" >
            <ReactMarkdown>
              {file.notes}
            </ReactMarkdown>
          </Card>
        </Col>
      </Row>
    </>
  )
}
