import { afterEach, describe, expect, it, vi } from 'vitest'
import { renderHook } from '@testing-library/react'
import useRefetchWhenStale from './useRefetchWhenStale'

const setTabVisibility = (state) => {
  Object.defineProperty(document, 'visibilityState', { value: state, configurable: true })
  document.dispatchEvent(new Event('visibilitychange'))
}

describe('useRefetchWhenStale', () => {
  afterEach(() => {
    vi.useRealTimers()
    delete document.visibilityState // back to jsdom's own
  })

  it('reloads when the tab becomes visible again', () => {
    const refetch = vi.fn()
    renderHook(() => useRefetchWhenStale(refetch))
    setTabVisibility('hidden')
    expect(refetch).not.toHaveBeenCalled()
    setTabVisibility('visible')
    expect(refetch).toHaveBeenCalledTimes(1)
  })

  it('reloads every minute, and stops when unmounted', () => {
    vi.useFakeTimers()
    const refetch = vi.fn()
    const { unmount } = renderHook(() => useRefetchWhenStale(refetch))
    vi.advanceTimersByTime(60000)
    expect(refetch).toHaveBeenCalledTimes(1)
    unmount()
    vi.advanceTimersByTime(120000)
    expect(refetch).toHaveBeenCalledTimes(1)
  })
})
