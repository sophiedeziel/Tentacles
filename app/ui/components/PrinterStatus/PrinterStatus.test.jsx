import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import PrinterStatus from './PrinterStatus'

describe('PrinterStatus', () => {
  it('shows the state text in a tag coloured by its family', () => {
    render(<PrinterStatus family="PRINTING" text="Printing from SD" />)
    const tag = screen.getByText('Printing from SD').closest('.ant-tag')
    expect(tag).toHaveClass('ant-tag-purple')
    expect(screen.getByRole('img', { name: '3D printer' })).toBeInTheDocument()
  })

  it.each([
    ['PAUSED', 'ant-tag-warning'],
    ['OPERATIONAL', 'ant-tag-success'],
    ['ERROR', 'ant-tag-error']
  ])('uses the %s colour', (family, className) => {
    render(<PrinterStatus family={family} text="State" />)
    expect(screen.getByText('State').closest('.ant-tag')).toHaveClass(className)
  })

  it('shows a dot and the text as a badge', () => {
    render(<PrinterStatus family="PAUSED" text="Paused" variant="badge" />)
    expect(screen.getByText('Paused')).toHaveClass('ant-badge-status-text')
  })

  it('shows the icon alone, titled with the state', () => {
    render(<PrinterStatus family="OFFLINE" text="Offline" variant="icon" />)
    expect(screen.getByTitle('Offline')).toHaveStyle({ color: '#8c8c8c' })
    expect(screen.queryByText('Offline')).not.toBeInTheDocument()
  })
})
