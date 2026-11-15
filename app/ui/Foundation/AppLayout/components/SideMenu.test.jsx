import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import SideMenu from './SideMenu'

const renderAt = (path) => render(
  <MemoryRouter initialEntries={[path]}>
    <SideMenu />
  </MemoryRouter>
)

describe('SideMenu', () => {
  it('links to the pages that exist', () => {
    renderAt('/files')

    expect(screen.getByText('Dashboard')).toBeInTheDocument()
    expect(screen.getByText('Printers')).toBeInTheDocument()
    expect(screen.getByText('Files')).toBeInTheDocument()
  })

  it('hides the links to pages that do not exist yet', () => {
    renderAt('/files')

    expect(screen.queryByText('Projects')).not.toBeInTheDocument()
    expect(screen.queryByText('Macros')).not.toBeInTheDocument()
    expect(screen.queryByText('Reports')).not.toBeInTheDocument()
    expect(screen.queryByText('Operations')).not.toBeInTheDocument()
  })

  it('selects Dashboard on the dashboard', () => {
    renderAt('/')

    expect(screen.getByText('Dashboard').closest('li')).toHaveClass('ant-menu-item-selected')
  })
})
