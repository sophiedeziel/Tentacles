import React from 'react'

import { useQuery } from '@apollo/client/react'
import { Link, useNavigate } from 'react-router'
import { Button, Card, List } from 'antd'
import { PlusOutlined } from '@ant-design/icons'
import { PageHeader } from '@ant-design/pro-layout'

import Printers from './graphql/Printers.graphql'

import EmptyState from 'components/EmptyState/EmptyState'
import PrinterAvatar from 'components/PrinterAvatar/PrinterAvatar'

import * as classes from 'common/Common.module.less'

export default function QueuesList () {
  const navigate = useNavigate()
  const { loading, error, data: printersData } = useQuery(Printers)

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { printers } = printersData

  return (
    <>
      <PageHeader
        className="site-page-header"
        ghost={false}
        onBack={() => window.history.back()}
        title="Print Queues"
        >
      </PageHeader>
      <Card
        className={classes.pageCard}
        title="Printers"
      >
        <List
          itemLayout="horizontal"
          dataSource={printers}
          locale={{
            emptyText: (
              <EmptyState kind="printers" title="No printers yet" description="Add a printer to give it a print queue.">
                <Button type="primary" icon={<PlusOutlined />} onClick={() => navigate('/printers/add')}>Add Printer</Button>
              </EmptyState>
            )
          }}
          renderItem={printer => (
            <List.Item>
              <List.Item.Meta
                avatar={<PrinterAvatar printer={printer} />}
                title={ <Link to={`/printers/${printer.id}/queue`}>{printer.name}</Link> }
                description={`${printer.jobsCount} jobs in queue`}
              />
            </List.Item>
          )}
        />
      </Card>
    </>
  )
}
