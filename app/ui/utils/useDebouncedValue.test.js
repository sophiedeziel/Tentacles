import { act, renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'

import useDebouncedValue from './useDebouncedValue'

describe('useDebouncedValue', () => {
  afterEach(() => vi.useRealTimers())

  it('returns the first value at once', () => {
    const { result } = renderHook(() => useDebouncedValue({ copies: 1 }, 300))

    expect(result.current).toEqual({ copies: 1 })
  })

  it('takes the last value of a burst, `delay` ms after it', () => {
    vi.useFakeTimers()
    const { result, rerender } = renderHook(({ value }) => useDebouncedValue(value, 300),
      { initialProps: { value: { copies: 1 } } })

    rerender({ value: { copies: 2 } })
    act(() => vi.advanceTimersByTime(200))
    rerender({ value: { copies: 3 } })
    act(() => vi.advanceTimersByTime(200))
    expect(result.current).toEqual({ copies: 1 })

    act(() => vi.advanceTimersByTime(100))
    expect(result.current).toEqual({ copies: 3 })
  })

  it('keeps the same value for a new object with the same contents', () => {
    vi.useFakeTimers()
    const { result, rerender } = renderHook(({ value }) => useDebouncedValue(value, 300),
      { initialProps: { value: { copies: 1 } } })
    const first = result.current

    rerender({ value: { copies: 1 } })
    act(() => vi.advanceTimersByTime(300))

    expect(result.current).toBe(first)
  })
})
