import React from 'react'
import { useQuery } from '@apollo/client'
import { Card, Form, Input, Button, Space } from 'antd'

import SearchNetworkPrinters from './graphql/SearchNetworkPrinters.graphql'

export default function PrinterAdd () {
  const { loading, error, data } = useQuery(SearchNetworkPrinters)

  const AddPrinterButtons = () => {
    if (loading) return (<></>)
    if (error) return (<></>)

    return (
      <Space>
        {
          data.searchNetworkPrinters.map((ip) => {
            return (
              <Button key={ip} type="primary">{ip}</Button>
            )
          })
        }
      </Space>
    )
  }

  return (
    <>
      <Card title="Add a printer from network scan">
        <AddPrinterButtons />
      </Card>
      <Card title="Add a printer">
        <Form layout="vertical">

          <Form.Item label="Printer name">
            <Input />
          </Form.Item>

          </Form>
      </Card>
    </>
  )
}
