import React from 'react'
import { useMatch } from 'react-router'
import { useSubscription, useMutation } from '@apollo/client/react'

import { Progress, Button } from 'antd'
import { PageHeader } from '@ant-design/pro-layout'

import PrintTable from './components/PrintTable'

import PrinterSubscription from './graphql/PrinterSubscription.graphql'
import StartNextPrint from './graphql/StartNextPrint.graphql'

export default function Queue () {
  const match = useMatch('/printers/:id/queue')
  const printerID = match.params.id

  const [startNextPrint] = useMutation(StartNextPrint)

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

  const handleStart = () => {
    startNextPrint({
      variables: {
        input: {
          printerId: printerID
        }
      }
    })
  }

  /* eslint-disable react/prop-types */
  const CurrentJob = ({ activeJob, enqueuedJobs }) => {
    if (activeJob !== undefined) {
      return (
        <>
          <h2>Active</h2>
          <>
            <p>{activeJob.executable?.filename}</p>
            <Progress percent={activeJob.progress} />
          </>
        </>
      )
    } else if (enqueuedJobs.length > 0) {
      return (
        <>
          <h2>Next job</h2>
          <p>{enqueuedJobs[0].executable?.filename}</p>
          <Button type="primary" onClick={handleStart}>Start next job</Button>
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
        <CurrentJob activeJob={activeJob} enqueuedJobs={enqueuedJobs} />
      </PageHeader>

      <br />
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
