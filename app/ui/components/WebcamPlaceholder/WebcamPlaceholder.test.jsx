import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import WebcamPlaceholder from './WebcamPlaceholder'

describe('WebcamPlaceholder', () => {
  it('shows the message and the hint', () => {
    render(<WebcamPlaceholder message="Camera offline" hint="Kobra 2 is offline" />)
    expect(screen.getByText('Camera offline')).toBeInTheDocument()
    expect(screen.getByText('Kobra 2 is offline')).toBeInTheDocument()
  })

  it('can go without a hint', () => {
    const { container } = render(<WebcamPlaceholder message="Camera offline" />)
    expect(container.textContent).toBe('Camera offline')
  })
})
