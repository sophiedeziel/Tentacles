import { useEffect, useState } from 'react'

// The current time, refreshed every `interval` ms: one dashboard-wide clock re-renders the times left
export default function useNow (interval = 30000) {
  const [now, setNow] = useState(() => Date.now())

  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), interval)
    return () => clearInterval(timer)
  }, [interval])

  return now
}
