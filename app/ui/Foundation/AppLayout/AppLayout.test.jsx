import React from 'react'
import { describe, expect, it } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import AppLayout from './AppLayout'

const renderLayout = () => render(
  <MemoryRouter initialEntries={['/']}>
    <AppLayout>Page</AppLayout>
  </MemoryRouter>
)

describe('AppLayout', () => {
  it('collapses the sider to the tentacle mark and expands it back', () => {
    const { container } = renderLayout()
    const sider = container.querySelector('.ant-layout-sider')
    const trigger = container.querySelector('.ant-layout-sider-trigger')

    expect(sider).not.toHaveClass('ant-layout-sider-collapsed')
    expect(screen.getByText('Tentacles')).toBeInTheDocument()

    fireEvent.click(trigger)
    expect(sider).toHaveClass('ant-layout-sider-collapsed')
    expect(screen.queryByText('Tentacles')).not.toBeInTheDocument()
    expect(screen.getByRole('img', { name: 'Tentacles' })).toBeInTheDocument()

    fireEvent.click(trigger)
    expect(sider).not.toHaveClass('ant-layout-sider-collapsed')
    expect(screen.getByText('Tentacles')).toBeInTheDocument()
  })
})
