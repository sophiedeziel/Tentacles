import 'core-js/stable'
import 'regenerator-runtime/runtime'

import React from 'react'
import { createRoot } from 'react-dom/client'

import App from '../Foundation/App/App'

document.addEventListener('DOMContentLoaded', () => {
  const rootElement = document.getElementById('root')
  const root = createRoot(rootElement)

  root.render(
    <App name="React" />,
    document.body.appendChild(document.createElement('div'))
  )
})
