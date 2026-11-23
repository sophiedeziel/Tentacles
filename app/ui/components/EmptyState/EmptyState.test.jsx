import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import { Button } from 'antd'
import EmptyState from './EmptyState'

describe('EmptyState', () => {
  it('shows the illustration, the title, the description and the actions', () => {
    const { container } = render(
      <EmptyState kind="printers" title="No printers yet"
        description="Add your first printer to queue files and watch prints from here.">
        <Button type="primary">Add Printer</Button>
        <Button>Scan Network</Button>
      </EmptyState>
    )

    expect(container.querySelector('.ant-empty-image svg')).toBeInTheDocument()
    expect(screen.getByText('No printers yet')).toBeInTheDocument()
    expect(screen.getByText('Add your first printer to queue files and watch prints from here.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Add Printer' }).closest('.ant-empty-footer')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Scan Network' })).toBeInTheDocument()
  })

  it('draws its illustration out of the accessibility tree: the title says it all', () => {
    const { container } = render(<EmptyState kind="queue" title="Nothing yet" />)
    const svg = container.querySelector('.ant-empty-image svg')

    expect(svg).toHaveAttribute('aria-hidden', 'true')
    expect(svg).toHaveAttribute('viewBox', '0 0 160 120')
    expect(svg.querySelectorAll('path').length).toBeGreaterThan(1)
  })

  it('can go without a description or actions', () => {
    const { container } = render(<EmptyState kind="printers" title="No printers yet" />)

    expect(container.querySelector('.ant-empty-description').textContent).toBe('No printers yet')
    expect(container.querySelector('.ant-empty-footer')).not.toBeInTheDocument()
  })
})
