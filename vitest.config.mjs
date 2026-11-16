import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

const APP_DIR = fileURLToPath(new URL('./app/ui', import.meta.url))

// .graphql documents, parsed with gql as webpack's graphql-tag/loader does: each `#import "./Fragment.graphql"` line
// appends that fragment's document
const graphql = {
  name: 'graphql',
  transform (source, id) {
    if (!/\.(graphql|gql)$/.test(id)) return null
    const imports = [...source.matchAll(/^#import "(.+)"$/gm)].map(([, path]) => path)
    const fragments = imports.map((_, index) => `fragment${index}`)
    return [
      "import { gql } from '@apollo/client'",
      ...imports.map((path, index) => `import ${fragments[index]} from ${JSON.stringify(path)}`),
      `export default gql(${JSON.stringify([source, ...imports.map(() => '\n')])}, ${fragments.join(', ')})`
    ].join('\n')
  }
}

// Frontend unit tests: `bin/yarn test`. Test files sit next to the code, as *.test.js(x).
export default defineConfig({
  plugins: [react(), graphql],
  // Shakapacker resolves bare paths from app/ui: 'components/…', 'common/…' and 'graphql/….graphql' (not the package)
  resolve: {
    alias: [
      { find: /^(components|common)\//, replacement: `${APP_DIR}/$1/` },
      { find: /^graphql\/(.+\.graphql)$/, replacement: `${APP_DIR}/graphql/$1` }
    ]
  },
  // Tests don't need postcss.config.js (its plugins aren't installed): CSS modules only need their class names
  css: { postcss: {} },
  test: {
    environment: 'jsdom',
    include: ['app/ui/**/*.test.{js,jsx}'],
    setupFiles: ['app/ui/test/setup.js'],
    css: true
  }
})
