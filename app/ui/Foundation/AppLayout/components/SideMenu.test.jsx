import React from 'react'
import { describe, expect, it } from 'vitest'
import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { MockedProvider } from '@apollo/client/testing/react'
import { MemoryRouter, useLocation, useNavigate } from 'react-router'
import SideMenu, { menuKeys } from './SideMenu'
import { GLOBAL_QUEUE_ENABLED } from '../../../Sections/Queue/graphql/queue'

function CurrentPath () {
  return <span data-testid="path">{useLocation().pathname}</span>
}

function GoToAddPrinter () {
  const navigate = useNavigate()
  return <button onClick={() => navigate('/printers/add')}>Go</button>
}

// globalQueue is null while the global queue's flag is off. `answered` is called when the menu gets the answer.
const flag = (on, answered = () => {}) => ({
  request: { query: GLOBAL_QUEUE_ENABLED },
  result: () => {
    answered()
    return { data: { globalQueue: on ? { __typename: 'GlobalQueue', dispatchPaused: false } : null } }
  }
})

const renderMenu = (path, children, { queue = false, answered } = {}) => render(
  <MockedProvider mocks={[flag(queue, answered)]}>
    <MemoryRouter initialEntries={[path]}>{children}</MemoryRouter>
  </MockedProvider>
)

const renderAt = (path, options) => renderMenu(path, <><SideMenu /><CurrentPath /></>, options)

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
    ['/printers/3', ['/printers/manage'], ['printers']],
    ['/queue', ['/queue'], []]
  ])('on %s selects %j and opens %j', (path, selectedKeys, openKeys) => {
    expect(menuKeys(path)).toEqual({ selectedKeys, openKeys })
  })
})

describe('SideMenu', () => {
  it('links to the pages that exist', () => {
    renderAt('/files')

    expect(screen.getByText('Dashboard')).toBeInTheDocument()
    expect(screen.getByText('Printers')).toBeInTheDocument()
    expect(screen.getByText('Files')).toBeInTheDocument()
  })

  it('shows Printers with the 3D printer icon', () => {
    renderAt('/files')

    expect(within(item('Printers')).getByRole('img', { name: '3D printer' })).toBeInTheDocument()
  })

  it('hides the links to pages that do not exist yet', () => {
    renderAt('/files')

    expect(screen.queryByText('Projects')).not.toBeInTheDocument()
    expect(screen.queryByText('Macros')).not.toBeInTheDocument()
    expect(screen.queryByText('Reports')).not.toBeInTheDocument()
    expect(screen.queryByText('Operations')).not.toBeInTheDocument()
  })

  it('hides Print Queue while the global queue is off', async () => {
    let answered = false
    renderAt('/printers', { answered: () => { answered = true } })

    await waitFor(() => expect(answered).toBe(true))
    await act(() => new Promise((resolve) => setTimeout(resolve, 0)))
    expect(screen.getByText('Print Queues')).toBeInTheDocument()
    expect(screen.queryByText('Print Queue')).not.toBeInTheDocument()
  })

  it('links to the global queue right after the dashboard while it is on', async () => {
    renderAt('/printers', { queue: true })

    expect(await screen.findByText('Print Queue')).toBeInTheDocument()
    const entries = [...document.querySelectorAll('.ant-menu-root > li')].map((entry) => entry.textContent)
    expect(entries).toEqual(['Dashboard', 'Print Queue', 'PrintersPrint QueuesManage', 'Files'])

    fireEvent.click(screen.getByText('Print Queue'))
    expect(screen.getByTestId('path')).toHaveTextContent('/queue')
    expect(item('Print Queue')).toHaveClass('ant-menu-item-selected')
    expect(item('Printers')).not.toHaveClass('ant-menu-submenu-open')
  })

  it('selects Dashboard on the dashboard', () => {
    renderAt('/')

    expect(item('Dashboard')).toHaveClass('ant-menu-item-selected')
    expect(item('Printers')).not.toHaveClass('ant-menu-submenu-open')
  })

  it.each(['/printers/manage', '/printers/add', '/printers/3'])('opens Printers and selects Manage on %s', (path) => {
    renderAt(path)

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
    renderMenu('/files', <><SideMenu /><GoToAddPrinter /></>)

    expect(item('Printers')).not.toHaveClass('ant-menu-submenu-open')
    fireEvent.click(screen.getByText('Go'))
    expect(item('Printers')).toHaveClass('ant-menu-submenu-open')
  })

  it('leaves Printers closed while the sider is collapsed, where it would pop up', () => {
    renderMenu('/files', <><SideMenu collapsed /><GoToAddPrinter /></>)

    fireEvent.click(screen.getByText('Go'))
    expect(item('Printers')).not.toHaveClass('ant-menu-submenu-open')
  })
})