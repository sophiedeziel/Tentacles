import { useCallback, useEffect, useRef } from 'react'

// A stable function that runs `callback` `delay` ms after its last call: a burst of calls runs it once. The latest
// `callback` runs, and nothing runs after unmount.
export default function useDebouncedCallback (callback, delay) {
  const latest = useRef(callback)
  const timer = useRef(null)

  useEffect(() => { latest.current = callback }, [callback])
  useEffect(() => () => clearTimeout(timer.current), [])

  return useCallback(() => {
    clearTimeout(timer.current)
    timer.current = setTimeout(() => latest.current(), delay)
  }, [delay])
}
