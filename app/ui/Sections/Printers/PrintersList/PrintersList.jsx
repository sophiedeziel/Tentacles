import React from 'react'

import { useQuery } from '@apollo/client/react'
import { Link } from 'react-router'
import { Empty, List, Avatar, Button, Card } from 'antd'
import { PageHeader } from '@ant-design/pro-layout'

import Printers from './graphql/Printers.graphql'
import NetworkPrinters from './NetworkPrinters'

import * as classes from 'common/Common.module.less'

export default function PrintersList () {
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
      title="Printers management"
      extra={<Button type="primary"><Link to={'/printers/add'}>Configure a new printer</Link></Button>}
    >
    </PageHeader>

      <NetworkPrinters />

      <Card
        className={classes.pageCard}
        title="Configured printers"
      >
        <List
          className={classes.pageCardList}
          itemLayout="horizontal"
          dataSource={printers}
          locale={{ emptyText: <Empty description="Configure a printer to see it here" /> }}
          renderItem={printer => (
            <List.Item>
              <List.Item.Meta
                avatar={<Avatar src={`${printer.octoprintUri}/static/img/apple-touch-icon-114x114.png`} />}
                title={printer.name}
                description={printer.octoprintVersion} />
            </List.Item>
          )}
        />
      </Card>
      </>
  )
}
