import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import WidgetFrame from './WidgetFrame'

describe('WidgetFrame', () => {
  it('shows the widget as it is in view mode', () => {
    render(<WidgetFrame label="Printer"><button>Pause</button></WidgetFrame>)
    expect(screen.getByRole('button', { name: 'Pause' })).toBeInTheDocument()
  })

  it('makes the widget inert in edit mode', () => {
    render(<WidgetFrame label="Printer" editing><button>Pause</button></WidgetFrame>)
    expect(screen.getByText('Pause').closest('[inert]')).not.toBeNull()
  })
})
