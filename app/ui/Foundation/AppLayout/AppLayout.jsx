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
  },
  components: {
    Layout: {
      headerBg: '#110028',
      siderBg: '#110028'
    },
    Menu: {
      darkItemBg: '#110028',
      darkSubMenuItemBg: '#080014'
    }
  }
}

const lightTheme = {
  algorithm: [theme.defaultAlgorithm],
  token: {
    colorPrimary: '#722ed1'
  },
  components: {
    Layout: {
      headerBg: '#110028',
      siderBg: '#110028'
    },
    Menu: {
      darkItemBg: '#110028',
      darkSubMenuItemBg: '#080014'
    }
  }
}

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
            <div className={classes.Logo} >Tentacles</div>
            <SideMenu></SideMenu>
          </Sider>
        </ConfigProvider>
          <Layout >
            <Header className={classes.Header} style={{ padding: 0 }}>
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
