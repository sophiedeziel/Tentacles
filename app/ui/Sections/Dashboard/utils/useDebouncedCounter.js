import { useCallback, useEffect, useRef, useState } from 'react'

// A counter that goes up `delay` ms after the last bump: a burst of bumps (ten files enqueued at once) counts once.
// Returns [count, bump].
export default function useDebouncedCounter (delay) {
  const [count, setCount] = useState(0)
  const timer = useRef(null)

  const bump = useCallback(() => {
    clearTimeout(timer.current)
    timer.current = setTimeout(() => setCount((current) => current + 1), delay)
  }, [delay])

  useEffect(() => () => clearTimeout(timer.current), [])

  return [count, bump]
}
