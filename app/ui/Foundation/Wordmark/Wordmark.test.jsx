import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import Wordmark from './Wordmark'

describe('Wordmark', () => {
  it('shows the mark next to the name', () => {
    const { container } = render(<Wordmark />)

    expect(screen.getByText('Tentacles')).toBeInTheDocument()
    expect(container.querySelector('svg')).toHaveAttribute('aria-hidden', 'true')
  })
})
