const { webpackConfig: baseWebpackConfig, merge } = require('shakapacker')

other = {
  module: {
    rules: [
      {
        test: /\.(graphql|gql)$/,
        exclude: /node_modules/,
        loader: "graphql-tag/loader"
      },
      // {
      //   test: /\.css$/,
      //   use: [
      //     {
      //       loader: 'css-loader',
      //       options: {
      //         modules: true
      //       }
      //     }
      //   ]
      // },
      {
        test: /\.less$/,
        use: [
          { 
            loader: 'less-loader', 
            options: { 
              lessOptions: { 
                javascriptEnabled: true
              },
            } 
          },
        ]
      },
    ],
  },
}

module.exports = merge(baseWebpackConfig, other)