import React from 'react'

import { useQuery } from '@apollo/client/react'
import { Link } from 'react-router'
import { Card, List, Empty, Avatar } from 'antd'
import { PageHeader } from '@ant-design/pro-layout'

import Printers from './graphql/Printers.graphql'

import * as classes from 'common/Common.module.less'

export default function QueuesList () {
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
          locale={ { emptyText: <Empty description="No printers" /> } }
          renderItem={printer => (
            <List.Item>
              <List.Item.Meta
                avatar={<Avatar src={`${printer.octoprintUri}/static/img/apple-touch-icon-114x114.png`} />}
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
