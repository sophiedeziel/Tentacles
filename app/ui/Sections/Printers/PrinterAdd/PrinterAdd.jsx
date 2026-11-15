import React, { useState } from 'react'
import { useQuery, useLazyQuery, useMutation } from '@apollo/client/react'
import { Card, Form, Input, Button, Space, message } from 'antd'
import { PageHeader } from '@ant-design/pro-layout'
import useInterval from '../../../utils/UseInterval'

import SearchNetworkPrinters from './graphql/SearchNetworkPrinters.graphql'
import PrinterName from './graphql/PrinterName.graphql'
import AddPrinter from './graphql/AddPrinter.graphql'

import * as classes from 'common/Common.module.less'

export default function PrinterAdd () {
  const [delay] = useState(1000)
  const [isRunning, setIsRunning] = useState(false)
  const [apiRequestToken, setApiRequestToken] = useState()
  const [apiRequestIP, setApiRequestIP] = useState()
  const [octoprintTab, setOctoprintTab] = useState()

  useInterval(() => {
    pollAPIKey()
  }, isRunning ? delay : null)

  const { loading, error, data } = useQuery(SearchNetworkPrinters)
  const [printerQuery] = useLazyQuery(PrinterName)
  const [addPrinter] = useMutation(AddPrinter)

  const pollAPIKey = () => {
    fetch(`http://${apiRequestIP}/plugin/appkeys/request/${apiRequestToken}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    }).then((response) => {
      if (response.status === 200) {
        setIsRunning(false)
        return (response.json())
      }
    }).then((data) => {
      if (data?.api_key) {
        octoprintTab.close()
        const uri = `http://${apiRequestIP}/`
        printerQuery({ variables: { uri, secret: data.api_key } }).then(({ data: printerData, error }) => {
          if (error) throw error
          sendAddPrinter(printerData.identifyPrinter.name || apiRequestIP, uri, data.api_key)
        }).catch((error) => {
          message.error(error.message)
        })
      }
    }).catch((error) => {
      console.error('pollAPIKey', error)
    })
  }

  const sendAddPrinter = (name, uri, secret) => {
    addPrinter({ variables: { input: { name, uri, secret } } }).then(({ data, error }) => {
      if (error) throw error
      const { errors } = data.addPrinter
      if (errors.length > 0) {
        message.error(errors.join('. '))
        return
      }
      window.location.href = '/printers/manage'
    }).catch((error) => {
      message.error(error.message)
    })
  }

  const handleCreateSubmit = (values) => {
    sendAddPrinter(values.name, values.uri, values.secret)
  }

  const requestAPIKey = (ip) => {
    fetch(`http://${ip}/plugin/appkeys/request`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ app: 'Tentacles' })
    }).then((response) => {
      if (response.status === 201) {
        return (response.json())
      }
    }).then(({ app_token: appToken }) => {
      setIsRunning(true)
      setApiRequestToken(appToken)
      setApiRequestIP(ip)
      setOctoprintTab(window.open(
        `http://${ip}`, '_blank'))
    }).catch(() => {
      window.open(`http://${ip}`, '_blank')
    })
  }

  const AddPrinterButtons = () => {
    if (loading) return (<>Scanning</>)
    if (error) return (<></>)

    return (
      <Space>
        {
          data.searchNetworkPrinters.map((ip) => {
            return (
              <Button key={ip} type="primary" onClick={() => { requestAPIKey(ip) }}>{ip}</Button>
            )
          })
        }
      </Space>
    )
  }

  return (
    <>
      <PageHeader
        className="site-page-header"
        ghost={false}
        onBack={() => window.history.back()}
        title="Back to printer's management"
      >
      </PageHeader>

      <Card
        className={classes.pageCard}
        title="Add a printer from network scan"
      >
        <AddPrinterButtons />
      </Card>

      <Card
        className={classes.pageCard}
        title="Add a printer"
      >
        <Form
          layout="vertical"
          onFinish={handleCreateSubmit}
          >

          <Form.Item label="Printer name" name="name">
            <Input />
          </Form.Item>

          <Form.Item label="URI" name="uri">
            <Input />
          </Form.Item>

          <Form.Item label="API key" name="secret">
            <Input />
          </Form.Item>

          <Form.Item>
            <Button type="primary" htmlType="submit">
              Add printer
            </Button>
          </Form.Item>

      </Form>
      </Card>
    </>
  )
}
