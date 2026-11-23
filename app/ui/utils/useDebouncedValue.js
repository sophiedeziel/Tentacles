import { useEffect, useState } from 'react'

// `value`, `delay` ms after it last changed: a burst of changes gives one. Changes are compared by value (JSON), so a
// new object with the same contents isn't a change. The first value is returned at once.
export default function useDebouncedValue (value, delay) {
  const [debounced, setDebounced] = useState(value)
  const key = JSON.stringify(value)

  useEffect(() => {
    const settle = () => setDebounced((current) => (JSON.stringify(current) === key ? current : JSON.parse(key)))
    const timer = setTimeout(settle, delay)
    return () => clearTimeout(timer)
  }, [key, delay])

  return debounced
}
