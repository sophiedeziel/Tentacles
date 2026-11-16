import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import FleetSummary from './FleetSummary'

const printer = (stateFamily) => ({ status: { stateFamily } })

// The figure under a label, and the colour of its bar
const figure = (label) => {
  const statistic = screen.getByText(label).closest('.ant-statistic')
  return {
    value: statistic.querySelector('.ant-statistic-content-value').textContent,
    bar: statistic.previousElementSibling
  }
}

describe('FleetSummary', () => {
  it('counts the printers by state family', () => {
    render(<FleetSummary printers={[
      printer('PRINTING'), printer('PRINTING'), printer('OPERATIONAL'), printer('PAUSED'),
      printer('ERROR'), printer('OFFLINE'), printer('CANCELLING'), printer('CONNECTING')
    ]} />)

    expect(figure('Printing').value).toBe('2')
    expect(figure('Ready').value).toBe('1')
    expect(figure('Paused').value).toBe('1')
    expect(figure('Needs Attention').value).toBe('3')
  })

  it('counts a printer without a status as offline', () => {
    render(<FleetSummary printers={[{ status: null }]} />)
    expect(figure('Needs Attention').value).toBe('1')
  })

  it('takes counts per state family instead of printers', () => {
    render(<FleetSummary counts={{ PRINTING: 4, OPERATIONAL: 2, ERROR: 1, OFFLINE: 2, CONNECTING: 5 }} />)

    expect(figure('Printing').value).toBe('4')
    expect(figure('Ready').value).toBe('2')
    expect(figure('Paused').value).toBe('0')
    expect(figure('Needs Attention').value).toBe('3')
  })

  it('shows zeros for an empty fleet', () => {
    render(<FleetSummary />)
    expect(['Printing', 'Ready', 'Paused', 'Needs Attention'].map((label) => figure(label).value))
      .toEqual(['0', '0', '0', '0'])
  })

  it.each([
    ['Printing', '#722ed1'],
    ['Ready', '#52c41a'],
    ['Paused', '#faad14'],
    ['Needs Attention', '#ff4d4f']
  ])('draws the %s bar in its state colour', (label, color) => {
    render(<FleetSummary />)
    expect(figure(label).bar).toHaveStyle({ background: color })
  })
})
