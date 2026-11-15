import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import TentacleMark from './TentacleMark'

describe('TentacleMark', () => {
  it('is hidden from assistive tech when it has no title', () => {
    const { container } = render(<TentacleMark />)
    expect(container.querySelector('svg')).toHaveAttribute('aria-hidden', 'true')
  })

  it('is labelled when given a title', () => {
    render(<TentacleMark title="Tentacles" />)
    expect(screen.getByRole('img', { name: 'Tentacles' })).toBeInTheDocument()
  })

  it('draws the purple mark by default', () => {
    const { container } = render(<TentacleMark size={48} />)
    expect(container.querySelector('svg')).toHaveAttribute('width', '48')
    expect(container.querySelector('path')).toHaveAttribute('fill', '#722ed1')
    expect(container.querySelectorAll('circle')).toHaveLength(10)
  })

  it('draws the reversed mark for the dark navigation', () => {
    const { container } = render(<TentacleMark variant="reversed" />)
    expect(container.querySelector('path')).toHaveAttribute('fill', '#a565ff')
    expect(container.querySelector('circle')).toHaveAttribute('fill', '#d3adf7')
  })
})
