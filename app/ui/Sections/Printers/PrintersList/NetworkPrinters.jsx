import React, { useEffect, useState } from 'react'

import { useQuery, useLazyQuery, useMutation } from '@apollo/client/react'
import { message, notification, Space, Button, Card } from 'antd'

import useInterval from 'utils/UseInterval'

import SearchNetworkPrinters from './graphql/SearchNetworkPrinters.graphql'
import PrinterName from './graphql/PrinterName.graphql'
import AddPrinter from './graphql/AddPrinter.graphql'

import * as classes from 'common/Common.module.less'

export default function NetworkPrinters () {
  const { loading, error, data } = useQuery(SearchNetworkPrinters)
  const [delay] = useState(1000)
  const [isRunning, setIsRunning] = useState(false)
  const [apiRequestToken, setApiRequestToken] = useState()
  const [apiRequestIP, setApiRequestIP] = useState()
  const [octoprintTab, setOctoprintTab] = useState()
  const [api, contextHolder] = notification.useNotification()

  useInterval(() => {
    pollAPIKey()
  }, isRunning ? delay : null)

  useEffect(() => {
    if (data && data.searchNetworkPrinters.length > 0) {
      api.info({
        message: `${printers.length} printers found on the network`,
        // TODO: Add a link to the documentation to explain how to allow CORS
        description:
          'Click on the button with the IP address of the printer you want to add. You will be redirected to your octorpint instance to accept the API key request. You will have to allow CORS on Octoprint first.'
      })
    }
  }, [data])

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
    addPrinter({ variables: { input: { backend: 'OCTOPRINT', name, uri, secret } } }).then(({ data, error }) => {
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

  if (error) return (<></>)

  if (loading) return (<></>)

  const { searchNetworkPrinters: printers } = data

  if (printers.length !== 0) {
    // setPrintersFound(true)
    return (
      <Card
        className={classes.pageCard}
        title="Add a printer from network scan"
      >
        {contextHolder}
        <Space>
        {
          data.searchNetworkPrinters.map((ip) => {
            return (
              <Button key={ip} type="primary" onClick={() => { requestAPIKey(ip) }}>{ip}</Button>
            )
          })
        }
      </Space>
    </Card>
    )
  } else {
    return (<></>)
  }
}
