import js from '@eslint/js'
import react from 'eslint-plugin-react'
import globals from 'globals'

export default [
  js.configs.recommended,
  {
    ignores: [
      'node_modules/**',
      'build/**',
      '**/schema.graphql',
      '**/*.graphql.d.ts',
      'Procfile',
      'public/**',
      'vendor/**',
      'tmp/**',
      'coverage/**',
      'eslint.config.js'
    ]
  },
  // Node.js config files
  {
    files: ['*.config.js', 'config/**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'commonjs',
      globals: {
        ...globals.node
      }
    }
  },
  // React/Browser source files
  {
    files: ['app/ui/**/*.{js,jsx}'],
    plugins: {
      react
    },
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      parserOptions: {
        ecmaFeatures: {
          jsx: true
        }
      },
      globals: {
        ...globals.browser,
        ...globals.es2021,
        require: 'readonly' // For dynamic imports
      }
    },
    settings: {
      react: {
        version: 'detect'
      }
    },
    rules: {
      ...react.configs.recommended.rules,
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'react/react-in-jsx-scope': 'off' // Not needed with React 17+
    }
  }
]
