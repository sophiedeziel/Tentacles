import React from 'react'

import { Card, Progress, Row, Col } from 'antd'

import { useQuery } from '@apollo/client'
import Printers from './graphql/Printers.graphql'

export default function Dashboard () {
  const { loading, error, data: printersData } = useQuery(Printers)

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { printers } = printersData

  return (
    <Row>
      {
        printers.map((printer) => {
          return (
            <Col span={8} key={printer.id} >
              <Card>
                {printer.name}<br/>
                Status: {printer.jobStatus}<br/>
                File: CR10s_Hook.gcode
                <Progress percent={Math.floor(Math.random() * 100)} />
              </Card>
            </Col>
          )
        })
      }
    </Row>
  )
}
