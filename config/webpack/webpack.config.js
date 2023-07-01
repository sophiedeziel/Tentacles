const { merge, generateWebpackConfig } = require('shakapacker')
const webpackConfig = generateWebpackConfig()

const MonacoWebpackPlugin = require('monaco-editor-webpack-plugin')

const path = require('path')
const APP_DIR = path.resolve(__dirname, './app/ui')
const MONACO_DIR = path.resolve(__dirname, './node_modules/monaco-editor')

const options = {
  resolve: {
    fallback: {
      fs: false
    }
  },
  cache: {
    type: 'filesystem'
  },
  plugins: [
    new MonacoWebpackPlugin({
      languages: ['gcode']
    })
  ],
  module: {
    rules: [
      {
        test: /\.(graphql|gql)$/,
        exclude: /node_modules/,
        loader: 'graphql-tag/loader'
      },
      {
        test: /\.less$/,
        use: [
          {
            loader: 'less-loader',
            options: {
              lessOptions: {
                modifyVars: {
                  'primary-color': '#722ed1',
                  'layout-header-background': '#120338'
                },
                javascriptEnabled: true
              }
            }
          }
        ]
      },
      {
        test: /\.css$/,
        include: APP_DIR,
        use: [{
          loader: 'style-loader'
        }, {
          loader: 'css-loader',
          options: {
            modules: true,
            namedExport: true
          }
        }]
      }, {
        test: /\.css$/,
        include: MONACO_DIR,
        use: ['style-loader', 'css-loader']
      }
    ]
  }
}

module.exports = merge({}, webpackConfig, options)
