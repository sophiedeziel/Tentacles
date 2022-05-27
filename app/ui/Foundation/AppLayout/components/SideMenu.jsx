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
import { useLocation, useNavigate } from 'react-router-dom'

const rootSubmenuKeys = ['printers', 'macros', 'reports']
const { SubMenu } = Menu

function SideMenu () {
  const location = useLocation()
  const { pathname } = location
  const navigate = useNavigate()

  const getRootFromLocation = (path = pathname) => {
    return (path.split('/').filter(e => e)[0] || '/')
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

  const onSelect = ({ item, key, keyPath, selectedKeys, domEvent }) => {
    navigate(key)
    if (rootSubmenuKeys.indexOf(getRootFromLocation(key)) === -1) {
      setOpenKeys([])
    }
  }

  return (
    <Menu
    defaultSelectedKeys={['1']}
    mode="inline"
    onOpenChange={onOpenChange}
    openKeys={openKeys}
    onSelect={onSelect}
    selectedKeys={[getRootFromLocation(), pathname]}
    theme="dark"
    >
    <Menu.Item key="/" icon={<PieChartOutlined />} >
      Dashboard
    </Menu.Item>
    <Menu.Item key="/projects" icon={<BookOutlined />}>
      Projects
    </Menu.Item>
    <SubMenu key="printers" icon={<UsbOutlined />} title="Printers">
      <Menu.Item key="/printers">Print Queues</Menu.Item>
      <Menu.Item key="/printers/manage">Manage</Menu.Item>
      <Menu.Item key="/printers/operations">Operations</Menu.Item>
    </SubMenu>
    <Menu.Item key="/files" icon={<FileOutlined />}>
      Files
    </Menu.Item>
    <Menu.Item key="/macros" icon={<CodeOutlined />}>
      Macros
    </Menu.Item>
    <Menu.Item key="/reports" icon={<BarChartOutlined />}>
      Reports
    </Menu.Item>
    </Menu>
  )
}

export default SideMenu
