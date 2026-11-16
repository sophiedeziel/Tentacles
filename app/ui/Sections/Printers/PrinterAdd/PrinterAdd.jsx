import React, { useEffect, useState } from 'react'
import { Link, useSearchParams } from 'react-router'
import { App, Card, Typography } from 'antd'
import { ArrowLeftOutlined } from '@ant-design/icons'

import NetworkCard from './NetworkCard'
import PrinterForm from './PrinterForm'
import * as classes from './PrinterAdd.module.less'

// Add Printer, at /printers/add: an OctoPrint server found on the network (approved in OctoPrint, added by the
// server), or any printer entered by hand. Both end on the new printer's page. ?connect=<address> (the fleet list's
// Connect) starts that address's approval once: the parameter is dropped so a reload doesn't ask OctoPrint again.
export default function PrinterAdd () {
  const [params, setParams] = useSearchParams()
  const [connectTo] = useState(() => params.get('connect'))

  useEffect(() => {
    if (params.has('connect')) setParams({}, { replace: true })
  }, [params, setParams])

  return (
    <App>
      <div className={classes.page}>
        <div className={classes.heading}>
          <Link to="/printers/manage" className={classes.back}><ArrowLeftOutlined /> Printers</Link>
          <Typography.Title level={3} style={{ margin: 0 }}>Add Printer</Typography.Title>
          <span className={classes.muted}>
            Tentacles connects to a printer through its server, OctoPrint or PrusaLink. Pick one found on your
            network, or enter its details yourself.
          </span>
        </div>
        <div className={classes.cards}>
          <NetworkCard connectTo={connectTo} />
          <Card className={classes.manualCard} title={<h2 className={classes.cardTitle}>Enter Details Manually</h2>}>
            <PrinterForm />
          </Card>
        </div>
      </div>
    </App>
  )
}
