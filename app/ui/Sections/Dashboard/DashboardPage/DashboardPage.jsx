import React from 'react'
import { Typography } from 'antd'

// The redesigned dashboard, served at /dashboard-next until it replaces the one at /.
// View mode only for now: the sections, widgets and live data come in the next layers.
export default function DashboardPage () {
  return (
    <div>
      <Typography.Title level={3} style={{ margin: 0 }}>Dashboard</Typography.Title>
    </div>
  )
}
