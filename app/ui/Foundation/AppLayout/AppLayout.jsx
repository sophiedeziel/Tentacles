import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { ConfigProvider, Layout, Menu, theme } from 'antd'
import {
  BugOutlined
} from '@ant-design/icons'

import 'antd/dist/reset.css'
import SideMenu from './components/SideMenu'

import classes from './AppLayout.module.less'

const { Header, Content, Sider } = Layout

const darkTheme = {
  algorithm: [theme.darkAlgorithm],
  token: {
    colorPrimary: '#a565ff'
  }
}

const lightTheme = {
  algorithm: [theme.defaultAlgorithm],
  token: {
    colorPrimary: '#722ed1'
  }
}

function AppLayout ({ children }) {
  const [collapsed, setCollaped] = useState(false)

  const onCollapse = () => {
    setCollaped(!collapsed)
  }

  return (
    <ConfigProvider theme={ lightTheme } >
      <Layout style={{ minHeight: '100vh' }}>
        <ConfigProvider theme={darkTheme}>
          <Sider collapsible collapsed={collapsed} onCollapse={onCollapse} trigger={null} >
            <div className={classes.Logo} >Tentacles</div>
            <SideMenu></SideMenu>
          </Sider>
        </ConfigProvider>
          <Layout >
            <Header className={classes.Header} style={{ padding: 0 }}>
              <Menu mode="horizontal" style={{ float: 'right' }}>
                <Menu.Item key='bugs'>
                  <a href="https://github.com/sophiedeziel/Tentacles/issues" target="_blank" rel="noreferrer">
                    <BugOutlined />
                  </a>
                </Menu.Item>
              </Menu>
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
