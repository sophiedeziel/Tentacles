import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, renderHook } from '@testing-library/react'
import useDebouncedCounter from './useDebouncedCounter'

describe('useDebouncedCounter', () => {
  afterEach(() => vi.useRealTimers())

  it('counts a burst of bumps once, after the delay', () => {
    vi.useFakeTimers()
    const { result } = renderHook(() => useDebouncedCounter(500))
    act(() => {
      result.current[1]()
      vi.advanceTimersByTime(300)
      result.current[1]()
      vi.advanceTimersByTime(300)
      result.current[1]()
    })
    expect(result.current[0]).toBe(0)
    act(() => vi.advanceTimersByTime(500))
    expect(result.current[0]).toBe(1)
    act(() => {
      result.current[1]()
      vi.advanceTimersByTime(500)
    })
    expect(result.current[0]).toBe(2)
  })

  it('stops counting when unmounted', () => {
    vi.useFakeTimers()
    const { result, unmount } = renderHook(() => useDebouncedCounter(500))
    act(() => result.current[1]())
    unmount()
    expect(() => vi.advanceTimersByTime(1000)).not.toThrow()
    expect(result.current[0]).toBe(0)
  })
})
