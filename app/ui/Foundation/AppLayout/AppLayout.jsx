import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { ConfigProvider, Layout, Menu } from 'antd'
import {
  BugOutlined
} from '@ant-design/icons'

import 'antd/dist/reset.css'
import SideMenu from './components/SideMenu'
import TentacleMark from '../../components/TentacleMark/TentacleMark'
import { darkTheme, lightTheme } from '../theme'

import * as classes from './AppLayout.module.less'

const { Header, Content, Sider } = Layout

function AppLayout ({ children }) {
  const [collapsed, setCollaped] = useState(false)

  const onCollapse = () => {
    setCollaped(!collapsed)
  }

  const items = [
    {
      label: <a href="https://github.com/sophiedeziel/Tentacles/issues" target="_blank" rel="noreferrer">
                <BugOutlined />
              </a>,
      key: 'bugs'
    }
  ]

  return (
    <ConfigProvider theme={ lightTheme } >
      <Layout style={{ minHeight: '100vh' }}>
        <ConfigProvider theme={darkTheme}>
          <Sider collapsible collapsed={collapsed} onCollapse={onCollapse} trigger={null} >
            <div className={classes.logo}>
              <TentacleMark size={40} variant="reversed" title={collapsed ? 'Tentacles' : undefined} />
              {!collapsed && <span className={classes.name}>Tentacles</span>}
            </div>
            <SideMenu></SideMenu>
          </Sider>
        </ConfigProvider>
          <Layout >
            <Header className={classes.header} style={{ padding: 0 }}>
              <Menu mode="horizontal" style={{ float: 'right' }} items={items} />
            </Header>
            <Content style={{ padding: 24 }}>
              {children}
            </Content>
          </Layout>

      </Layout>
    </ConfigProvider>
  )
}

AppLayout.propTypes = {
  children: PropTypes.node
}

export default AppLayout
