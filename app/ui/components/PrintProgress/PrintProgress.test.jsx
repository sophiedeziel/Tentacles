import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import PrintProgress from './PrintProgress'

const MINUTE = 60 * 1000

const bar = (container) => container.querySelector('.ant-progress')

describe('PrintProgress', () => {
  it('shows the time left while printing, in the printing colour', () => {
    const { container } = render(<PrintProgress family="PRINTING" progress={52.4} timeLeft={52 * MINUTE} />)

    expect(screen.getByText('52 min left')).toBeInTheDocument()
    expect(screen.getByText('52%')).toBeInTheDocument()
    expect(bar(container).querySelector('.ant-progress-track')).toHaveStyle({ backgroundColor: '#722ed1' })
  })

  it('falls back to the percentage when the printer does not say how long is left', () => {
    render(<PrintProgress family="PRINTING" progress={8} />)
    expect(screen.getByText('8% printed')).toBeInTheDocument()
  })

  it('says where a paused print stopped', () => {
    render(<PrintProgress family="PAUSED" progress={31} timeLeft={20 * MINUTE} />)
    expect(screen.getByText('Paused at 31%')).toBeInTheDocument()
    expect(screen.queryByText(/left/)).not.toBeInTheDocument()
  })

  it('says where a cancelled print stops', () => {
    render(<PrintProgress family="CANCELLING" progress={64} />)
    expect(screen.getByText('Stopping at 64%')).toBeInTheDocument()
  })

  it('keeps the state colour and no tick at 100%', () => {
    const { container } = render(<PrintProgress family="PRINTING" progress={100} timeLeft={0} />)

    expect(bar(container)).not.toHaveClass('ant-progress-status-success')
    expect(screen.getByText('< 1 min left')).toBeInTheDocument()
  })

  it('shows the bar alone in other states', () => {
    const { container } = render(<PrintProgress family="OPERATIONAL" progress={0} />)
    expect(container.textContent).toBe('0%')
  })
})
