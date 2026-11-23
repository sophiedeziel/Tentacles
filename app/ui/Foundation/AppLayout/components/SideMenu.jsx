import React, { useEffect, useState } from 'react'
import PropTypes from 'prop-types'
import { Menu } from 'antd'
import { FileOutlined, PieChartOutlined } from '@ant-design/icons'
import { useLocation, useNavigate } from 'react-router'

import { Printer3DOutlined } from '../../../components/icons'
import useQueueEnabled from '../../../Sections/Queue/useQueueEnabled'

const PRINTERS_SUBMENU = 'printers'

// The menu item to select and the submenu to open on a page.
// Printers: /printers/:id/queue is a print queue; the printer pages (manage, add, /printers/:id) belong to Manage.
// The global queue (/queue) sits in Printers beside the per-printer queues until the cutover.
export function menuKeys (pathname) {
  const [section, page, subpage] = pathname.split('/').filter(Boolean)

  if (section === 'queue') return { selectedKeys: ['/queue'], openKeys: [PRINTERS_SUBMENU] }

  if (section === 'printers') {
    let selected = []
    if (!page || subpage === 'queue') selected = ['/printers']
    else if (page === 'manage' || page === 'add' || /^\d+$/.test(page)) selected = ['/printers/manage']
    return { selectedKeys: selected, openKeys: [PRINTERS_SUBMENU] }
  }
  return { selectedKeys: ['/' + (section || '')], openKeys: [] }
}

// The sider's navigation. `collapsed` is the sider's: a collapsed menu shows submenus as hover popups, which
// must not be opened by navigating.
function SideMenu ({ collapsed = false }) {
  const { pathname } = useLocation()
  const navigate = useNavigate()
  const { enabled: queueEnabled } = useQueueEnabled()
  const { selectedKeys, openKeys: pageOpenKeys } = menuKeys(pathname)
  const pageSubmenu = pageOpenKeys[0]

  const [openKeys, setOpenKeys] = useState(pageOpenKeys)

  // The layout stays mounted between pages: reaching a page of a submenu (or expanding the sider on one) opens it
  useEffect(() => {
    if (pageSubmenu && !collapsed) {
      setOpenKeys((keys) => keys.includes(pageSubmenu) ? keys : [pageSubmenu])
    }
  }, [pageSubmenu, collapsed])

  const onOpenChange = (keys) => {
    const latestOpenKey = keys.find((key) => !openKeys.includes(key))

    // Opening Printers in the expanded menu also shows its first page. Collapsed, it opens on hover: no navigation.
    if (latestOpenKey === PRINTERS_SUBMENU && !collapsed) navigate('/printers')
    setOpenKeys(latestOpenKey ? [latestOpenKey] : keys)
  }

  const onSelect = ({ key }) => {
    navigate(key)
    if (menuKeys(key).openKeys.length === 0) setOpenKeys([])
  }

  // Only links to pages that exist: Projects, Operations, Macros and Reports come back with their pages. Global Queue
  // only while its flag is on.
  const items = [
    {
      label: 'Dashboard',
      key: '/',
      icon: <PieChartOutlined />
    },
    {
      label: 'Printers',
      key: PRINTERS_SUBMENU,
      icon: <Printer3DOutlined />,
      children: [
        {
          label: 'Print Queues',
          key: '/printers'
        },
        ...(queueEnabled ? [{ label: 'Global Queue', key: '/queue' }] : []),
        {
          label: 'Manage',
          key: '/printers/manage'
        }
      ]
    },
    {
      label: 'Files',
      key: '/files',
      icon: <FileOutlined />
    }
  ]

  return (
    <Menu
    mode="inline"
    onOpenChange={onOpenChange}
    openKeys={openKeys}
    onSelect={onSelect}
    selectedKeys={selectedKeys}
    theme={'dark'}
    items={items}
    />
  )
}

SideMenu.propTypes = {
  collapsed: PropTypes.bool
}

export default SideMenu
