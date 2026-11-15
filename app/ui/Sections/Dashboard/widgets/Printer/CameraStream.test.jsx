import React from 'react'
import { act, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import CameraStream from './CameraStream'
import { StreamVisibilityProvider } from '../../utils/useStreamWhenVisible'

let observers
class FakeIntersectionObserver {
  constructor (callback) {
    this.callback = callback
    this.elements = new Set()
    observers.push(this)
  }

  observe (element) { this.elements.add(element) }
  unobserve (element) { this.elements.delete(element) }
  disconnect () { this.elements.clear() }

  // Reports whether every observed element intersects the viewport
  report (isIntersecting) {
    act(() => this.callback([...this.elements].map((target) => ({ target, isIntersecting }))))
  }
}

const setTabVisibility = (state) => {
  Object.defineProperty(document, 'visibilityState', { value: state, configurable: true })
  act(() => { document.dispatchEvent(new Event('visibilitychange')) })
}

const cameras = (count = 1) => (
  <StreamVisibilityProvider>
    {Array.from({ length: count }, (_, index) => (
      <CameraStream key={index} url={`http://printer-${index}.local/webcam/?action=stream`} name={`Printer ${index}`}
        onError={() => {}} />
    ))}
  </StreamVisibilityProvider>
)

describe('CameraStream', () => {
  beforeEach(() => {
    observers = []
    vi.stubGlobal('IntersectionObserver', FakeIntersectionObserver)
    setTabVisibility('visible')
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    delete document.visibilityState // back to jsdom's own
  })

  it('shares one observer between every camera of the dashboard', () => {
    render(cameras(20))
    expect(observers).toHaveLength(1)
    expect(observers[0].elements.size).toBe(20)
  })

  it('streams only while in the viewport', () => {
    render(cameras())
    expect(screen.queryByRole('img')).not.toBeInTheDocument()

    observers[0].report(true)
    expect(screen.getByRole('img', { name: 'Printer 0 webcam' })).toHaveAttribute('src', 'http://printer-0.local/webcam/?action=stream')

    observers[0].report(false)
    expect(screen.queryByRole('img')).not.toBeInTheDocument()
  })

  it('unmounts the stream while the tab is hidden', () => {
    render(cameras())
    observers[0].report(true)

    setTabVisibility('hidden')
    expect(screen.queryByRole('img')).not.toBeInTheDocument()

    setTabVisibility('visible')
    expect(screen.getByRole('img')).toBeInTheDocument()
  })

  it('never streams outside a dashboard (the Add Widget gallery)', () => {
    render(<CameraStream url="http://printer.local/webcam/?action=stream" name="Printer" onError={() => {}} />)
    expect(observers).toHaveLength(0)
    expect(screen.queryByRole('img')).not.toBeInTheDocument()
  })
})
