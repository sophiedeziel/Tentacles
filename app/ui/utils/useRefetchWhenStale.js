import { useEffect } from 'react'

// Pushes can be missed (a dropped ActionCable connection sends nothing when it comes back), so the dashboard
// reloads its data when the tab becomes visible again and every `interval` ms
export default function useRefetchWhenStale (refetch, interval = 60000) {
  useEffect(() => {
    const onVisibilityChange = () => {
      if (document.visibilityState === 'visible') refetch()
    }
    document.addEventListener('visibilitychange', onVisibilityChange)
    const timer = setInterval(refetch, interval)
    return () => {
      document.removeEventListener('visibilitychange', onVisibilityChange)
      clearInterval(timer)
    }
  }, [refetch, interval])
}
