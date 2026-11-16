import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import JobStatus from './JobStatus'

describe('JobStatus', () => {
  it.each([
    ['completed', 'Completed', 'ant-tag-success', 'check-circle'],
    ['error', 'Failed', 'ant-tag-error', 'close-circle'],
    ['failed', 'Failed', 'ant-tag-error', 'close-circle'],
    ['cancelled', 'Cancelled', 'ant-tag-default', 'stop']
  ])('shows %s as %s, in the state palette, with its icon', (status, label, className, icon) => {
    render(<JobStatus status={status} />)
    const tag = screen.getByText(label).closest('.ant-tag')
    expect(tag).toHaveClass(className)
    expect(screen.getByRole('img', { name: icon })).toBeInTheDocument()
  })

  it('shows a status it does not know as stored, in grey without an icon', () => {
    render(<JobStatus status="skipped" />)
    expect(screen.getByText('Skipped').closest('.ant-tag')).toHaveClass('ant-tag-default')
    expect(screen.queryByRole('img')).not.toBeInTheDocument()
  })
})
