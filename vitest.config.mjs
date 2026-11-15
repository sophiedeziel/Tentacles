import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

// Frontend unit tests: `bin/yarn test`. Test files sit next to the code, as *.test.js(x).
export default defineConfig({
  plugins: [react()],
  // Tests don't need postcss.config.js (its plugins aren't installed): CSS modules only need their class names
  css: { postcss: {} },
  test: {
    environment: 'jsdom',
    include: ['app/ui/**/*.test.{js,jsx}'],
    setupFiles: ['app/ui/test/setup.js'],
    css: true
  }
})
