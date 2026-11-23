import React from 'react'
import { describe, expect, it } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter, useLocation, useNavigate } from 'react-router'
import SideMenu, { menuKeys } from './SideMenu'

function CurrentPath () {
  return <span data-testid="path">{useLocation().pathname}</span>
}

function GoToAddPrinter () {
  const navigate = useNavigate()
  return <button onClick={() => navigate('/printers/add')}>Go</button>
}

const renderAt = (path) => render(
  <MemoryRouter initialEntries={[path]}>
    <SideMenu />
    <CurrentPath />
  </MemoryRouter>
)

const item = (text) => screen.getByText(text).closest('li')

describe('menuKeys', () => {
  it.each([
    ['/', ['/'], []],
    ['/files', ['/files'], []],
    ['/files/12/print', ['/files'], []],
    ['/printers', ['/printers'], ['printers']],
    ['/printers/3/queue', ['/printers'], ['printers']],
    ['/printers/manage', ['/printers/manage'], ['printers']],
    ['/printers/add', ['/printers/manage'], ['printers']],
    ['/printers/3', ['/printers/manage'], ['printers']]
  ])('on %s selects %j and opens %j', (path, selectedKeys, openKeys) => {
    expect(menuKeys(path)).toEqual({ selectedKeys, openKeys })
  })
})

describe('SideMenu', () => {
  it('selects Dashboard on the dashboard', () => {
    renderAt('/')

    expect(item('Dashboard')).toHaveClass('ant-menu-item-selected')
    expect(item('Printers')).not.toHaveClass('ant-menu-submenu-open')
  })

  it('opens Printers and selects Manage on a printer page', () => {
    renderAt('/printers/3')

    expect(item('Printers')).toHaveClass('ant-menu-submenu-open')
    expect(item('Manage')).toHaveClass('ant-menu-item-selected')
    expect(item('Print Queues')).not.toHaveClass('ant-menu-item-selected')
  })

  it('selects Print Queues on a printer queue', () => {
    renderAt('/printers/3/queue')

    expect(item('Printers')).toHaveClass('ant-menu-submenu-open')
    expect(item('Print Queues')).toHaveClass('ant-menu-item-selected')
  })

  it('keeps Printers open when going to Manage', () => {
    renderAt('/printers')

    fireEvent.click(screen.getByText('Manage'))

    expect(screen.getByTestId('path')).toHaveTextContent('/printers/manage')
    expect(item('Printers')).toHaveClass('ant-menu-submenu-open')
    expect(item('Manage')).toHaveClass('ant-menu-item-selected')
  })

  it('closes Printers when going to another section', () => {
    renderAt('/printers/manage')

    fireEvent.click(screen.getByText('Files'))

    expect(screen.getByTestId('path')).toHaveTextContent('/files')
    expect(item('Printers')).not.toHaveClass('ant-menu-submenu-open')
  })

  it('opens Printers when a link elsewhere leads to a printer page', () => {
    render(
      <MemoryRouter initialEntries={['/files']}>
        <SideMenu />
        <GoToAddPrinter />
      </MemoryRouter>
    )

    expect(item('Printers')).not.toHaveClass('ant-menu-submenu-open')
    fireEvent.click(screen.getByText('Go'))
    expect(item('Printers')).toHaveClass('ant-menu-submenu-open')
  })

  it('leaves Printers closed while the sider is collapsed, where it would pop up', () => {
    render(
      <MemoryRouter initialEntries={['/files']}>
        <SideMenu collapsed />
        <GoToAddPrinter />
      </MemoryRouter>
    )

    fireEvent.click(screen.getByText('Go'))
    expect(item('Printers')).not.toHaveClass('ant-menu-submenu-open')
  })
})