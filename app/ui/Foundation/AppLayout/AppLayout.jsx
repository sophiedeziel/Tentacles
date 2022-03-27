import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { Layout, Menu } from 'antd'
import {
  BugOutlined
} from '@ant-design/icons'

import 'antd/dist/antd.less'
import SideMenu from './components/SideMenu'

import classes from './AppLayout.module.less'

const { Header, Content, Footer, Sider } = Layout

function AppLayout ({ children }) {
  const [collapsed, setCollaped] = useState(false)

  const onCollapse = () => {
    setCollaped(!collapsed)
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider collapsible collapsed={collapsed} onCollapse={onCollapse} trigger={null}>
        <div className={classes.Logo} >Tentacles</div>
        <SideMenu></SideMenu>
      </Sider>
      <Layout>
        <Header className={classes.siteLayoutBackground} style={{ padding: 0 }} >
          <Menu mode="horizontal" style={{ float: 'right' }}>
            <Menu.Item>
              <a href="https://github.com/sophiedeziel/Tentacles/issues" target="_blank" rel="noreferrer">
                <BugOutlined />
              </a>
            </Menu.Item>
          </Menu>
        </Header>
        <Content style={{ margin: '0 16px' }}>
          <div className="site-layout-background" style={{ padding: 24, minHeight: 360 }}>
            {children}
          </div>
        </Content>
        <Footer style={{ textAlign: 'center' }}>Tentacles</Footer>
      </Layout>
    </Layout>
  )
}

AppLayout.propTypes = {
  children: PropTypes.node
}

export default AppLayout
