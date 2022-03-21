import React from 'react'
import { Menu } from 'antd'
import {
  DesktopOutlined,
  PieChartOutlined,
  FileOutlined,
  TeamOutlined,
  UserOutlined
} from '@ant-design/icons'
import { useLocation, Link } from 'react-router-dom'
const { SubMenu } = Menu

function SideMenu () {
  const location = useLocation()
  const { pathname } = location

  return (
    <Menu
    theme="dark"
    defaultSelectedKeys={['1']}
    selectedKeys={['/' + pathname.split('/').filter(e => e)[0]]}
    mode="inline" >
    <Menu.Item key="/" icon={<PieChartOutlined />} >
      <Link to="/">Dashboard</Link>
    </Menu.Item>
    <Menu.Item key="/printers" icon={<DesktopOutlined />}>
      <Link to="/printers">Printers</Link>
    </Menu.Item>
    <Menu.Item key="/files" icon={<FileOutlined />} to='/files'>
      <Link to="/files">Files</Link>
    </Menu.Item>
    <SubMenu key="sub1" icon={<UserOutlined />} title="User">
      <Menu.Item key="4">Bill</Menu.Item>
      <Menu.Item key="5">Alex</Menu.Item>
      <Menu.Item key="6">Tom</Menu.Item>
    </SubMenu>
    <SubMenu key="sub2" icon={<TeamOutlined />} title="Team">
      <Menu.Item key="7">Team 1</Menu.Item>
      <Menu.Item key="8">Team 2</Menu.Item>
    </SubMenu>
    </Menu>
  )
}

export default SideMenu
