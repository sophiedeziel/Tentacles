import React from 'react'

import { useQuery } from '@apollo/client'
import { notification } from 'antd'

import SearchNetworkPrinters from './graphql/SearchNetworkPrinters.graphql'

export default function NetworkPrinters () {
  const { loading, error, data } = useQuery(SearchNetworkPrinters)

  if (error) return (<></>)

  if (loading) return (<></>)

  const { searchNetworkPrinters: printers } = data

  if (printers.length !== 0) {
    notification.info({
      message: `${printers.length} printers found on the network`,
      description:
        'This is the content of the notification. This is the content of the notification. This is the content of the notification.',
      duration: 0
    })
  }

  return (
    <>
    </>
  )
}
