import React from 'react'

import { Card, Progress, Row, Col } from 'antd'
import { EditOutlined, EllipsisOutlined, SettingOutlined } from '@ant-design/icons'

import { useQuery } from '@apollo/client/react'
import Printers from './graphql/Printers.graphql'

export default function Dashboard () {
  const { loading, error, data: printersData } = useQuery(Printers)

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { printers } = printersData

  return (
    <Row gutter={[12, 12]}>
      {
        printers.map((printer) => {
          return (
            <Col span={8} key={printer.id}>
              <Card
                cover={<img alt="webcam" src={printer.octoprintUri + 'webcam/?action=stream'} />}
                actions={[
                  <SettingOutlined key="setting" />,
                  <EditOutlined key="edit" />,
                  <EditOutlined key="edit" />,
                  <EditOutlined key="edit" />,
                  <EllipsisOutlined key="ellipsis" />
                ]}
              >
              <Card.Meta
                  title={printer.name}
                  description={printer.jobStatus}
                />
                <Progress percent={printer.currentJob?.progress} />
                {printer.currentJob?.name}
              </Card>
            </Col>
          )
        })
      }
    </Row>
  )
}
