import React from 'react'
import { useRouteMatch } from 'react-router'
import { useQuery } from '@apollo/client'
import ReactMarkdown from 'react-markdown'
import { GCodeViewer } from 'react-gcode-viewer'

import classes from './FilePrinter.module.less'

import { Col, Row, PageHeader, Card, Checkbox, Button, List, Statistic } from 'antd'

import File from './graphql/File.graphql'

export default function FilePrinter () {
  const match = useRouteMatch('/files/:id')
  const fileID = match.params.id

  const { loading, error, data: queryData } = useQuery(File, {
    variables: { id: fileID }
  })

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { file, printers } = queryData

  return (
    <>
      <PageHeader
        className="site-page-header"
        ghost={false}
        onBack={() => window.history.back()}
        title={file.filename}
      >
      </PageHeader>
      <Row className={classes.PrintersList} gutter={8}>
        <Col span={12}>
          <Card title="Select printers" >
            <List
              itemLayout="horizontal"
              dataSource={printers}
              renderItem={item => (
                <List.Item>
                  <List.Item.Meta
                    avatar={<Checkbox disabled={item.jobStatus !== 'Operational'}/>}
                    title={item.name}
                    description={item.jobStatus}
                  />
                </List.Item>
              )}
            />
            <Row style={{ marginTop: 12 }}>
              <Button type="primary">Send to printer</Button>
            </Row>
          </Card>
        </Col>
        <Col span={12}>
          <Card title="File Preview" >
            <GCodeViewer
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
            />
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
