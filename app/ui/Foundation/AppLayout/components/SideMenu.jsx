import React, { useState } from 'react'
import { Menu } from 'antd'
import {
  BarChartOutlined,
  BookOutlined,
  CodeOutlined,
  FileOutlined,
  PieChartOutlined,
  UsbOutlined
} from '@ant-design/icons'
import { useLocation, useNavigate } from 'react-router'

const rootSubmenuKeys = ['printers', 'macros', 'reports']

function SideMenu () {
  const location = useLocation()
  const { pathname } = location
  const navigate = useNavigate()

  const getRootFromLocation = (path = pathname) => {
    const root = '/' + (path.split('/').filter(e => e)[0] || '/')
    return root
  }

  const [openKeys, setOpenKeys] = useState([getRootFromLocation()])

  const onOpenChange = keys => {
    const latestOpenKey = keys.find(key => openKeys.indexOf(key) === -1)

    if (rootSubmenuKeys.indexOf(latestOpenKey) === -1) {
      setOpenKeys(keys)
    } else {
      navigate('/' + latestOpenKey)
      setOpenKeys(latestOpenKey ? [latestOpenKey] : [])
    }
  }

  const onSelect = ({ key }) => {
    navigate(key)
    if (rootSubmenuKeys.indexOf(getRootFromLocation(key)) === -1) {
      setOpenKeys([])
    }
  }

  const items = [
    {
      label: 'Dashboard',
      key: '/',
      icon: <PieChartOutlined />
    },
    {
      label: 'Projects',
      key: '/projects',
      icon: <BookOutlined />
    },
    {
      label: 'Printers',
      key: 'printers',
      icon: <UsbOutlined />,
      children: [
        {
          label: 'Print Queues',
          key: '/printers'
        },
        {
          label: 'Manage',
          key: '/printers/manage'
        },
        {
          label: 'Operations',
          key: '/printers/operations'
        }
      ]
    },
    {
      label: 'Files',
      key: '/files',
      icon: <FileOutlined />
    },
    {
      label: 'Macros',
      key: '/macros',
      icon: <CodeOutlined />
    },
    {
      label: 'Reports',
      key: '/reports',
      icon: <BarChartOutlined />
    }
  ]

  return (
    <Menu
    defaultSelectedKeys={['1']}
    mode="inline"
    onOpenChange={onOpenChange}
    openKeys={openKeys}
    onSelect={onSelect}
    selectedKeys={[getRootFromLocation(), pathname]}
    theme={'dark'}
    items={items}
    />
  )
}

export default SideMenu
