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

describe('PrinterStatus motion', () => {
  const variants = ['tag', 'badge', 'icon']
  // The element that carries the motion: the Tag, the Badge, or the icon's wrapper (titled with the state)
  const statusElement = (variant) => variant === 'icon'
    ? screen.getByTitle('State')
    : screen.getByText('State').closest('.ant-tag, .ant-badge')

  describe.each(variants)('as a %s', (variant) => {
    it('pulses while printing', () => {
      render(<PrinterStatus family="PRINTING" text="State" variant={variant} />)
      expect(statusElement(variant)).toHaveAttribute('data-motion', 'pulse')
    })

    it.each(['CONNECTING', 'CANCELLING'])('breathes while %s', (family) => {
      render(<PrinterStatus family={family} text="State" variant={variant} />)
      expect(statusElement(variant)).toHaveAttribute('data-motion', 'breathe')
    })

    it.each(['PAUSED', 'OPERATIONAL', 'ERROR', 'OFFLINE'])('stays still when %s', (family) => {
      render(<PrinterStatus family={family} text="State" variant={variant} />)
      expect(statusElement(variant)).not.toHaveAttribute('data-motion')
    })
  })
})
