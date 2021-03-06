import React from 'react'

import { useQuery } from '@apollo/client'
import Printers from './graphql/Printers.graphql'

export default function QueuesList () {
  const { loading, error, data: printersData } = useQuery(Printers)

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { printers } = printersData

  return (
    <>
      <ul>{
      printers.map((printer) => {
        return (
        <li key={printer.id}>
          {printer.name}, {printer.jobStatus}, {printer.jobsCount} jobs in queue
        </li>
        )
      })
      }
      </ul>
    </>
  )
}
