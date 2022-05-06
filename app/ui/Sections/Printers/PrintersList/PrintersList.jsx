import React from 'react'

import { useQuery } from '@apollo/client'
import { Link } from 'react-router-dom'
import { Empty, List, Avatar, Button, Card, PageHeader } from 'antd'

import Printers from './graphql/Printers.graphql'
import NetworkPrinters from './NetworkPrinters'

import classes from '../../../common/Common.module.less'

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
      <>
        <PageHeader
          className="site-page-header"
          ghost={false}
          title="Printers management"
        >
        </PageHeader>
        <Card
          className={classes.pageCard}
          title="Configured printers"
        >
          <List
            itemLayout="horizontal"
            dataSource={printers}
            renderItem={printer => (
              <List.Item>
                <List.Item.Meta
                  avatar={<Avatar src={`${printer.octoprintUri}/static/img/apple-touch-icon-114x114.png`} />}
                  title={ printer.name }
                  description={ printer.octoprintVersion }
                />
              </List.Item>
            )}
            footer={<Button type="primary"><Link to={'/printers/add'}>Configure a new printer</Link></Button>}
          />
        </Card>
      </>
    )
  }

  return (
    <>
      <NetworkPrinters />
      <DisplayPrintersList />
    </>
  )
}
