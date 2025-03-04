import { createRoot } from 'react-dom/client'
import 'core-js/stable'
import 'regenerator-runtime/runtime'

import React from 'react'

import App from '../Foundation/App/App'

document.addEventListener('DOMContentLoaded', () => {
  const root = createRoot(document.body.appendChild(document.createElement('div')))
  root.render(<App name="React" />)
})
