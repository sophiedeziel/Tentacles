import React from 'react'
import { describe, expect, it } from 'vitest'
import { fireEvent, render } from '@testing-library/react'
import { Printer3DOutlined } from '../icons'
import PrinterAvatar from './PrinterAvatar'

// The paths Printer3DOutlined draws, to tell it from antd's paper printer
const printer3DPaths = () => {
  const { container, unmount } = render(<Printer3DOutlined />)
  const paths = [...container.querySelectorAll('path')].map((path) => path.getAttribute('d'))
  unmount()
  return paths
}

const pathsIn = (container) => [...container.querySelectorAll('.anticon path')].map((path) => path.getAttribute('d'))

describe('PrinterAvatar', () => {
  it('shows the 3D printer icon for a printer without its own icon', () => {
    const expected = printer3DPaths()
    const { container } = render(<PrinterAvatar printer={{ backend: 'PRUSALINK', uri: 'http://mk4.local' }} />)

    expect(container.querySelector('img')).not.toBeInTheDocument()
    expect(pathsIn(container)).toEqual(expected)
  })

  it('draws it on a 40 px square tile, like the fleet list', () => {
    const { container } = render(<PrinterAvatar printer={{ backend: 'PRUSALINK' }} />)

    const avatar = container.querySelector('.ant-avatar')
    expect(avatar).toHaveClass('ant-avatar-square')
    expect(avatar).toHaveStyle({ width: '40px', height: '40px' })
  })

  it('keeps the icon out of the accessibility tree: the name next to it says it all', () => {
    const { container } = render(<PrinterAvatar printer={{ backend: 'PRUSALINK' }} />)

    expect(container.querySelector('.anticon')).toHaveAttribute('aria-hidden', 'true')
  })

  it("shows an OctoPrint server's own icon", () => {
    const { container } = render(<PrinterAvatar printer={{ backend: 'OCTOPRINT', uri: 'http://octopi.local/' }} />)

    expect(container.querySelector('img'))
      .toHaveAttribute('src', 'http://octopi.local/static/img/apple-touch-icon-114x114.png')
  })

  it("falls back to the 3D printer icon when the OctoPrint server's icon doesn't load", () => {
    const expected = printer3DPaths()
    const { container } = render(<PrinterAvatar printer={{ backend: 'OCTOPRINT', uri: 'http://octopi.local' }} />)

    fireEvent.error(container.querySelector('img'))

    expect(container.querySelector('img')).not.toBeInTheDocument()
    expect(pathsIn(container)).toEqual(expected)
  })
})
