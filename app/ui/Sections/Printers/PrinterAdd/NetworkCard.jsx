import React, { useCallback, useEffect, useState } from 'react'
import PropTypes from 'prop-types'
import { useNavigate } from 'react-router'
import { useQuery } from '@apollo/client/react'
import { Alert, App, Button, Card, Spin, Steps, Tag } from 'antd'
import { ReloadOutlined } from '@ant-design/icons'

import { Printer3DOutlined } from '../../../components/icons'
import useOctoprintAppKey from './useOctoprintAppKey'
import { ADD_NETWORK_PRINTERS } from './graphql/add'
import * as classes from './PrinterAdd.module.less'

const STEPS = [
  { title: 'Choose', content: 'Pick an address below' },
  { title: 'Approve in OctoPrint', content: 'Allow the access request' },
  { title: 'Added', content: 'Name and specs from OctoPrint' }
]

const NOT_ADDED = 'OctoPrint server, not added yet'
const DENIED = 'OctoPrint did not approve Tentacles, or the request expired. Connect to ask again.'

function Row ({ icon, address, detail, danger = false, waiting = false, children }) {
  return (
    <li className={waiting ? `${classes.row} ${classes.waiting}` : classes.row}>
      <div className={classes.rowText}>
        {icon}
        <div className={classes.lines}>
          <span className={classes.mono}>{address}</span>
          <span className={danger ? classes.danger : classes.muted}>{detail}</span>
        </div>
      </div>
      <div className={classes.rowActions}>{children}</div>
    </li>
  )
}

// One OctoPrint server found by the scan: Connect, the waiting request, or the printer already added at it.
// `autoConnect` (from ?connect=) starts the request, then `onAutoConnect` turns it off: it starts once.
function NetworkRow ({ entry, autoConnect, onAutoConnect, onStateChange }) {
  const navigate = useNavigate()
  const { address, printer } = entry
  const appKey = useOctoprintAppKey(address, { onAdded: (added) => navigate(`/printers/${added.id}`) })
  const { state, connect } = appKey

  useEffect(() => {
    if (!autoConnect) return
    onAutoConnect()
    connect() // does nothing while a request is under way, e.g. on StrictMode's second run
  }, [autoConnect, onAutoConnect, connect])

  useEffect(() => onStateChange(address, state), [address, state, onStateChange])

  const icon = (muted) => <Printer3DOutlined aria-hidden="true" className={muted ? classes.mutedIcon : classes.icon} />

  if (printer) {
    return <Row icon={icon(true)} address={address} detail={`Already added as ${printer.name}`}><Tag>Added</Tag></Row>
  }
  if (state === 'WAITING') {
    return (
      <Row waiting icon={<Spin size="small" />} address={address} detail="Waiting for you to approve Tentacles in OctoPrint">
        <Button key="open" size="small" onClick={appKey.openApproval}>Open OctoPrint Again</Button>
        <Button key="cancel" size="small" type="text" onClick={appKey.cancel}>Cancel Request</Button>
      </Row>
    )
  }
  if (state === 'ADDED') return <Row icon={icon(true)} address={address} detail="Added"><Tag>Added</Tag></Row>

  const detail = { DENIED, FAILED: appKey.error }[state] || NOT_ADDED
  return (
    <Row icon={icon(false)} address={address} detail={detail} danger={state === 'FAILED'}>
      <Button key="connect" type="primary" size="small" loading={appKey.requesting} onClick={connect}
        aria-label={`Connect ${address}`}>Connect</Button>
    </Row>
  )
}

// "From Your Network": the OctoPrint servers the scan found, each approved in OctoPrint then added by the server.
// `connectTo`: the address of ?connect=, whose request starts on its own once.
export default function NetworkCard ({ connectTo }) {
  const { message } = App.useApp()
  const { data, error, refetch } = useQuery(ADD_NETWORK_PRINTERS)
  const [scanning, setScanning] = useState(false)
  const [states, setStates] = useState({})
  const [pendingConnect, setPendingConnect] = useState(connectTo)
  const onAutoConnect = useCallback(() => setPendingConnect(null), [])
  const onStateChange = useCallback((address, state) => {
    setStates((current) => (current[address] === state ? current : { ...current, [address]: state }))
  }, [])

  const scan = async () => {
    setScanning(true)
    try {
      await refetch({ refresh: true })
    } catch (scanError) {
      message.error(`The network scan failed: ${scanError.message}`)
    } finally {
      setScanning(false)
    }
  }

  const flow = Object.values(states)
  const current = flow.includes('ADDED') ? 2 : flow.includes('WAITING') ? 1 : 0
  const entries = data?.networkPrinters

  let list
  if (entries?.length) {
    list = (
      <ul className={classes.rows} aria-label="OctoPrint servers on your network">
        {entries.map((entry) => (
          <NetworkRow key={entry.address} entry={entry} autoConnect={!entry.printer && entry.address === pendingConnect}
            onAutoConnect={onAutoConnect} onStateChange={onStateChange} />
        ))}
      </ul>
    )
  } else if (entries) {
    list = <p className={classes.muted}>No OctoPrint server answered the scan. Scan again, or enter its details.</p>
  } else if (error) {
    list = <Alert type="error" showIcon title="The network scan failed" description={error.message} />
  } else {
    list = <div className={classes.scanning}><Spin size="small" /> Scanning your network…</div>
  }

  return (
    <Card className={classes.scanCard} title={<h2 className={classes.cardTitle}>From Your Network</h2>}
      extra={<Button size="small" icon={<ReloadOutlined />} loading={scanning} onClick={scan}>Scan Again</Button>}>
      <div className={classes.cardBody}>
        <p className={classes.muted}>The scan finds OctoPrint servers. PrusaLink printers are added with the form.</p>
        <Steps size="small" current={current} items={STEPS} />
        {list}
      </div>
    </Card>
  )
}

const entryShape = PropTypes.shape({
  address: PropTypes.string.isRequired,
  printer: PropTypes.shape({ id: PropTypes.string.isRequired, name: PropTypes.string.isRequired })
})

Row.propTypes = {
  icon: PropTypes.node.isRequired,
  address: PropTypes.string.isRequired,
  detail: PropTypes.node,
  danger: PropTypes.bool,
  waiting: PropTypes.bool,
  children: PropTypes.node
}

NetworkRow.propTypes = {
  entry: entryShape.isRequired,
  autoConnect: PropTypes.bool.isRequired,
  onAutoConnect: PropTypes.func.isRequired,
  onStateChange: PropTypes.func.isRequired
}

NetworkCard.propTypes = { connectTo: PropTypes.string }
