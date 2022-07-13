const { webpackConfig: baseWebpackConfig, merge } = require('shakapacker')

const other = {

  resolve: {
    fallback: {
      fs: false
    }
  },
  cache: {
    type: 'filesystem'
  },
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
      }
    ]
  }
}

module.exports = merge(baseWebpackConfig, other)
