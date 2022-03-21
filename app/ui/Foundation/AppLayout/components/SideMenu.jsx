import React, { useState } from 'react'
import { Menu } from 'antd'
import {
  DesktopOutlined,
  PieChartOutlined,
  FileOutlined,
  TeamOutlined,
  UserOutlined
} from '@ant-design/icons'
import { useLocation, useHistory } from 'react-router-dom'

const rootSubmenuKeys = ['printers', 'macros', 'reports']
const { SubMenu } = Menu

function SideMenu () {
  const location = useLocation()
  const { pathname } = location
  const history = useHistory()

  const getRootFromLocation = (path = pathname) => {
    return (path.split('/').filter(e => e)[0] || '/')
  }

  const [openKeys, setOpenKeys] = useState([getRootFromLocation()])

  const onOpenChange = keys => {
    const latestOpenKey = keys.find(key => openKeys.indexOf(key) === -1)

    if (rootSubmenuKeys.indexOf(latestOpenKey) === -1) {
      setOpenKeys(keys)
    } else {
      history.push('/' + latestOpenKey)
      setOpenKeys(latestOpenKey ? [latestOpenKey] : [])
    }
  }

  const onSelect = ({ item, key, keyPath, selectedKeys, domEvent }) => {
    history.push(key)
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
    <SubMenu key="printers" icon={<DesktopOutlined />} title="Printers">
      <Menu.Item key="/printers">something</Menu.Item>
      <Menu.Item key="/printers/5">Alex</Menu.Item>
      <Menu.Item key="/printers/6">Tom</Menu.Item>
    </SubMenu>
    <Menu.Item key="/files" icon={<FileOutlined />}>
      Files
    </Menu.Item>
    <SubMenu key="macros" icon={<UserOutlined />} title="Macros">
      <Menu.Item key="/macros">Bill</Menu.Item>
      <Menu.Item key="/macros/10">Alex</Menu.Item>
      <Menu.Item key="/macros/11">Tom</Menu.Item>
    </SubMenu>
    <SubMenu key="reports" icon={<TeamOutlined />} title="Reports">
      <Menu.Item key="/reports">Team 1</Menu.Item>
      <Menu.Item key="/reports/8">Team 2</Menu.Item>
    </SubMenu>
    </Menu>
  )
}

export default SideMenu
