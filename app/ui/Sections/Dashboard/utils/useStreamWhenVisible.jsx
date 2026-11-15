import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react'
import PropTypes from 'prop-types'

const StreamVisibility = createContext(null)

const tabIsVisible = () => document.visibilityState === 'visible'

// One IntersectionObserver for the whole dashboard (tiles register with it, so 20+ cameras don't make 20+
// observers) and the tab's visibility. Without this provider (the Add Widget gallery), nothing streams.
export function StreamVisibilityProvider ({ children }) {
  const [tabVisible, setTabVisible] = useState(tabIsVisible)
  const callbacks = useRef(new Map())
  const observer = useRef(null)

  useEffect(() => {
    const onChange = () => setTabVisible(tabIsVisible())
    document.addEventListener('visibilitychange', onChange)
    return () => {
      document.removeEventListener('visibilitychange', onChange)
      observer.current?.disconnect()
      observer.current = null
    }
  }, [])

  // Calls `onChange(inViewport)` whenever the element enters or leaves the viewport; returns the unsubscribe
  const observe = useCallback((element, onChange) => {
    // threshold 0 and no root margin: "visible" means at least one pixel inside the tab's viewport
    observer.current ||= new IntersectionObserver((entries) => {
      entries.forEach((entry) => callbacks.current.get(entry.target)?.(entry.isIntersecting))
    }, { threshold: 0 })
    callbacks.current.set(element, onChange)
    observer.current.observe(element)
    return () => {
      callbacks.current.delete(element)
      observer.current?.unobserve(element)
    }
  }, [])

  const value = useMemo(() => ({ observe, tabVisible }), [observe, tabVisible])
  return <StreamVisibility.Provider value={value}>{children}</StreamVisibility.Provider>
}

StreamVisibilityProvider.propTypes = { children: PropTypes.node }

// Whether the element behind `ref` should stream: it is inside the viewport and the tab is visible
export default function useStreamWhenVisible (ref) {
  const visibility = useContext(StreamVisibility)
  const observe = visibility?.observe // stable: showing or hiding the tab doesn't re-observe every camera
  const [inViewport, setInViewport] = useState(false)

  useEffect(() => {
    if (!observe || !ref.current) return undefined
    return observe(ref.current, setInViewport)
  }, [observe, ref])

  return !!visibility && visibility.tabVisible && inViewport
}
