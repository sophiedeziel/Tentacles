import '@testing-library/jest-dom/vitest'
import { afterEach, vi } from 'vitest'
import { cleanup } from '@testing-library/react'

afterEach(() => {
  cleanup()
})

// jsdom has no matchMedia, which antd's responsive components need
if (!window.matchMedia) {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: vi.fn().mockImplementation((query) => ({
      matches: false,
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn()
    }))
  })
}

// Nor ResizeObserver, which antd's popups use
if (!window.ResizeObserver) {
  window.ResizeObserver = class {
    observe () {}
    unobserve () {}
    disconnect () {}
  }
}

// Nor IntersectionObserver: by default nothing is ever in the viewport (tests stub it to say otherwise)
if (!window.IntersectionObserver) {
  window.IntersectionObserver = class {
    observe () {}
    unobserve () {}
    disconnect () {}
  }
}
