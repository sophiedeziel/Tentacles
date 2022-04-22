import React from 'react'

import { useQuery } from '@apollo/client'
import { Empty } from 'antd'

import Printers from './graphql/Printers.graphql'
import NetworkPrinters from './NetworkPrinters'

export default function PrintersList () {
  const { loading, error, data: printersData } = useQuery(Printers)

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { printers } = printersData

  const DisplayPrintersList = () => {
    if (printers.length === 0) {
      return <Empty
        description="Configure a printer to see it here"
      />
    }
    return (
      <ul>{
        printers.map((printer) => {
          return (
          <li key={printer.id}>
            {printer.name}, {printer.octoprintVersion}
          </li>
          )
        })
        }
      </ul>
    )
  }

  return (
    <>
      <NetworkPrinters />
      <DisplayPrintersList />
    </>
  )
}
