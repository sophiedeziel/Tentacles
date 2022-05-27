import React from 'react'
import { useMatch } from 'react-router'
import { useQuery } from '@apollo/client'

import { PageHeader, Steps, Space } from 'antd'

import PrinterQuery from './graphql/PrinterQuery.graphql'

export default function Queue () {
  const match = useMatch('/printers/:id/queue')
  const printerID = match.params.id

  const { loading, error, data } = useQuery(PrinterQuery, { variables: { id: printerID } })

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { printer } = data
  const jobs = printer.jobs.edges.map(({ node }) => node)

  const completedJobs = jobs.filter(job => job.status === 'completed')
  const activeJobs = jobs.filter(job => job.status === 'active')
  const enqueuedJobs = jobs.filter(job => job.status === 'enqueued')

  const { Step } = Steps

  return (
    <>
    <Space direction="vertical" size="large">
      <PageHeader
        className="site-page-header"
        ghost={false}
        onBack={() => window.history.back()}
        title={printer.name}
        >
      </PageHeader>
      <Steps direction="vertical" current={completedJobs.length}>
        {[...completedJobs, ...activeJobs, ...enqueuedJobs].map(job => (
          <Step key={job.id} title={job.executable.filename} description={job.status} />
        ))}
      </Steps>
    </Space>
    </>
  )
}
