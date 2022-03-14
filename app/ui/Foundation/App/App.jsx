import React, {useState} from 'react';
import { Layout, Menu, Breadcrumb } from 'antd';
import {
  DesktopOutlined,
  PieChartOutlined,
  FileOutlined,
  TeamOutlined,
  UserOutlined,
} from '@ant-design/icons';

import PrintersList from '../../Sections/Printers/PrintersList/PrintersList'

const { Header, Content, Footer, Sider } = Layout;
const { SubMenu } = Menu;

import "antd/dist/antd.css";

import classes from './App.module.scss';

import { ApolloClient, HttpLink, InMemoryCache, ApolloProvider } from '@apollo/client';

import { setContext } from "@apollo/client/link/context";

const authLink = setContext((_, { headers }) => {
  const csrfToken = document?.querySelector("meta[name=csrf-token]")?.getAttribute("content");

  return {
    headers: {
      ...headers,
      "X-CSRF-Token": csrfToken,
    },
  };
});


const client = new ApolloClient({
  link: authLink.concat(new HttpLink({ uri: "/graphql" })),
  cache: new InMemoryCache(),
});

function App() {
  const [collapsed, setCollaped] = useState(false);

  const onCollapse = () => {
    setCollaped(!collapsed);
  }

  return (
    <ApolloProvider client={client}>
    <Layout style={{ minHeight: '100vh' }}>
        <Sider collapsible collapsed={collapsed} onCollapse={onCollapse} trigger={null}>
          <div className={classes.Logo} />
          <Menu theme="dark" defaultSelectedKeys={['1']} mode="inline">
            <Menu.Item key="1" icon={<PieChartOutlined />}>
              Dashboard
            </Menu.Item>
            <Menu.Item key="2" icon={<DesktopOutlined />}>
              Option 2
            </Menu.Item>
            <SubMenu key="sub1" icon={<UserOutlined />} title="User">
              <Menu.Item key="3">Tom</Menu.Item>
              <Menu.Item key="4">Bill</Menu.Item>
              <Menu.Item key="5">Alex</Menu.Item>
            </SubMenu>
            <SubMenu key="sub2" icon={<TeamOutlined />} title="Team">
              <Menu.Item key="6">Team 1</Menu.Item>
              <Menu.Item key="8">Team 2</Menu.Item>
            </SubMenu>
            <Menu.Item key="9" icon={<FileOutlined />}>
              Files
            </Menu.Item>
          </Menu>
        </Sider>
        <Layout>
          <Header className={classes.siteLayoutBackground} style={{ padding: 0 }} />
          <Content style={{ margin: '0 16px' }}>
            <Breadcrumb style={{ margin: '16px 0' }}>
              <Breadcrumb.Item>User</Breadcrumb.Item>
              <Breadcrumb.Item>Bill</Breadcrumb.Item>
            </Breadcrumb>
            <div className="site-layout-background" style={{ padding: 24, minHeight: 360 }}>
              <PrintersList />
            </div>
          </Content>
          <Footer style={{ textAlign: 'center' }}>Tentacles</Footer>
        </Layout>
      </Layout>
      </ApolloProvider>
  )
}

export default App;
