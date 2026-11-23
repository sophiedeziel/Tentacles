import { act, renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import useDebouncedCallback from './useDebouncedCallback'

describe('useDebouncedCallback', () => {
  afterEach(() => vi.useRealTimers())

  it('runs once, `delay` ms after the last call of a burst', () => {
    vi.useFakeTimers()
    const callback = vi.fn()
    const { result } = renderHook(() => useDebouncedCallback(callback, 300))

    act(() => {
      result.current()
      vi.advanceTimersByTime(200)
      result.current()
      vi.advanceTimersByTime(200)
      result.current()
    })
    expect(callback).not.toHaveBeenCalled()

    act(() => vi.advanceTimersByTime(300))
    expect(callback).toHaveBeenCalledTimes(1)
  })

  it('runs the latest callback', () => {
    vi.useFakeTimers()
    const first = vi.fn()
    const second = vi.fn()
    const { result, rerender } = renderHook(({ callback }) => useDebouncedCallback(callback, 300),
      { initialProps: { callback: first } })

    act(() => result.current())
    rerender({ callback: second })
    act(() => vi.advanceTimersByTime(300))

    expect(first).not.toHaveBeenCalled()
    expect(second).toHaveBeenCalledTimes(1)
  })

  it('runs nothing after unmount', () => {
    vi.useFakeTimers()
    const callback = vi.fn()
    const { result, unmount } = renderHook(() => useDebouncedCallback(callback, 300))

    act(() => result.current())
    unmount()
    vi.advanceTimersByTime(300)

    expect(callback).not.toHaveBeenCalled()
  })
})
