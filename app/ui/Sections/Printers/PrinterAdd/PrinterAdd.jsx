import React, { useState } from 'react'
import { useQuery, useLazyQuery, useMutation } from '@apollo/client'
import { Card, Form, Input, Button, Space } from 'antd'
import useInterval from '../../../utils/UseInterval'

import SearchNetworkPrinters from './graphql/SearchNetworkPrinters.graphql'
import PrinterName from './graphql/PrinterName.graphql'
import AddPrinter from './graphql/AddPrinter.graphql'

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
      console.log(data?.api_key)
      if (data?.api_key) {
        octoprintTab.close()
        printerQuery({ variables: { octoprintUri: `http://${apiRequestIP}/`, octoprintKey: data.api_key } }).then(({ data: printerData }) => {
          console.log(printerData)
          const name = printerData.octoprintName
          addPrinter({ variables: {input: { name: name, octoprintUri: `http://${apiRequestIP}/`, octoprintKey: data.api_key }} }).then(() => {
            console.log('Printer added')
          })
        })
      }
    }).catch((error) => {
      console.log(error)
    })
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
      <Card title="Add a printer from network scan">
        <AddPrinterButtons />
      </Card>
      <Card title="Add a printer">
        <Form layout="vertical">

          <Form.Item label="Printer name">
            <Input />
          </Form.Item>

          <Form.Item label="URI">
            <Input />
          </Form.Item>

          <Form.Item label="API key">
            <Input />
          </Form.Item>

          </Form>
      </Card>
    </>
  )
}
