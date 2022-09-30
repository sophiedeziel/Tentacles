import React from 'react'
import { useMatch } from 'react-router'
import { useSubscription } from '@apollo/client'

import { PageHeader, Progress } from 'antd'

import PrintTable from './components/PrintTable'

import PrinterSubscription from './graphql/PrinterSubscription.graphql'

export default function Queue () {
  const match = useMatch('/printers/:id/queue')
  const printerID = match.params.id

  const { loading, error, data } = useSubscription(PrinterSubscription, { variables: { id: printerID } })

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { printer } = data.printerSubscription
  const jobs = printer.jobs.edges.map(({ node }) => node)

  const completedJobs = jobs.filter(job => job.status === 'completed')
  const activeJob = jobs.filter(job => job.status === 'active')[0]
  const enqueuedJobs = jobs.filter(job => job.status === 'enqueued')

  const tableData = (jobs) => {
    return jobs.map((job, index) => ({
      ...job,
      key: job.id,
      index: index,
      filename: job.executable.filename
    }))
  }

  /* eslint-disable react/prop-types */
  const CurrentJob = ({ activeJob }) => {
    if (activeJob !== undefined) {
      return (
        <>
          <h2>Active</h2>
          <>
            {activeJob.executable?.filename}
            <Progress percent={activeJob.progress} />
          </>
        </>
      )
    } else {
      return (<></>)
    }
  }
  /* eslint-enable react/prop-types */

  return (
    <>
      <PageHeader
        className="site-page-header"
        ghost={false}
        onBack={() => window.history.back()}
        title={printer.name}
        >
        <CurrentJob activeJob={activeJob} />
      </PageHeader>

      <h2>Enqueued ({enqueuedJobs.length})</h2>
        <PrintTable
          jobs={tableData(enqueuedJobs)}
        />

        <br />

      <h2>History ({completedJobs.length})</h2>
        <PrintTable
          jobs={tableData(completedJobs)}
        />
    </>
  )
}
