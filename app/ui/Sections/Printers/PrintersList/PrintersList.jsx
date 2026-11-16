import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { useNavigate } from 'react-router'
import { useQuery } from '@apollo/client/react'
import { Alert, App, Button, Skeleton, Typography } from 'antd'
import { PlusOutlined, ReloadOutlined } from '@ant-design/icons'

import EmptyState from '../../../components/EmptyState/EmptyState'
import FleetSummary from '../../../components/FleetSummary/FleetSummary'
import useNow from '../../Dashboard/utils/useNow'
import useFleetLiveUpdates from '../../../utils/useFleetLiveUpdates'
import FleetTable from './FleetTable'
import { FLEET_PAGE, NETWORK_PRINTERS } from './graphql/fleet'
import * as classes from './PrintersList.module.less'

const DESCRIPTION = 'Every printer Tentacles talks to, its connection and what it is doing now.'

// The OctoPrint servers on the network that aren't added yet, each with a Connect button to the Add Printer page
function ScanBanner ({ addresses }) {
  const navigate = useNavigate()
  if (addresses.length === 0) return null
  const instances = addresses.length === 1 ? '1 OctoPrint instance' : `${addresses.length} OctoPrint instances`
  return (
    <section aria-labelledby="found-title" className={classes.banner}>
      <div className={classes.bannerText}>
        <h2 id="found-title" className={classes.sectionTitle}>{instances} found on your network</h2>
        <span className={classes.muted}>Connect asks OctoPrint to approve Tentacles, then adds the printer.</span>
      </div>
      <div className={classes.addresses}>
        {addresses.map((address) => (
          <div key={address} className={classes.address}>
            <span className={classes.mono}>{address}</span>
            <Button type="primary" size="small" aria-label={`Connect ${address}`}
              onClick={() => navigate(`/printers/add?connect=${encodeURIComponent(address)}`)}>Connect</Button>
          </div>
        ))}
      </div>
    </section>
  )
}

function FleetPage () {
  const { message } = App.useApp()
  const navigate = useNavigate()
  // cache-and-network: coming back to the page never shows (and acts on) statuses cached earlier
  const { data, error, refetch } = useQuery(FLEET_PAGE, { fetchPolicy: 'cache-and-network' })
  useFleetLiveUpdates(refetch)
  const network = useQuery(NETWORK_PRINTERS)
  const [scanning, setScanning] = useState(false)
  const now = useNow()

  const scan = async () => {
    setScanning(true)
    try {
      await network.refetch({ refresh: true })
    } catch (scanError) {
      message.error(`The network scan failed: ${scanError.message}`)
    } finally {
      setScanning(false)
    }
  }

  if (error && !data) return <Alert type="error" title="Could not load the printers" description={error.message} />
  if (!data) return <Skeleton active />

  const { printers } = data
  const found = (network.data?.networkPrinters || []).filter((entry) => !entry.printer).map((entry) => entry.address)
  const scanButton = <Button icon={<ReloadOutlined />} loading={scanning} onClick={scan}>Scan Network</Button>
  const addButton = (
    <Button type="primary" icon={<PlusOutlined />} onClick={() => navigate('/printers/add')}>Add Printer</Button>
  )

  return (
    <div className={classes.page}>
      <div className={classes.header}>
        <div className={classes.heading}>
          <Typography.Title level={3} style={{ margin: 0 }}>Printers</Typography.Title>
          <span className={classes.muted}>
            {printers.length > 0 ? `${DESCRIPTION} Favorites stay at the top.` : DESCRIPTION}
          </span>
        </div>
        {printers.length > 0 && <div className={classes.buttons}>{scanButton}{addButton}</div>}
      </div>
      {printers.length > 0
        ? (
          <>
            <FleetSummary printers={printers} />
            <ScanBanner addresses={found} />
            <FleetTable printers={printers} now={now} />
          </>
          )
        : (
          <>
            <section aria-label="No printers yet" className={classes.empty}>
              <EmptyState kind="printers" title="No printers yet"
                description="Add your first printer to queue files and watch prints from here.">
                {addButton}{scanButton}
              </EmptyState>
            </section>
            <ScanBanner addresses={found} />
          </>
          )}
    </div>
  )
}

ScanBanner.propTypes = { addresses: PropTypes.arrayOf(PropTypes.string).isRequired }

// The fleet list, at /printers/manage: every printer live (useFleetLiveUpdates), filtered and searched on the client.
// With no printer yet it shows the first-run empty state instead.
export default function PrintersList () {
  return <App><FleetPage /></App>
}
