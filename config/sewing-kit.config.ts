/* eslint-env node */
import {resolve} from 'path';

import {Plugins, Env} from '@shopify/sewing-kit';

const ROOT_PATH = resolve(__dirname, '..');

export default function sewingKitConfig(plugins: Plugins, env: Env) {
  return {
    name: 'tentacles',
    plugins: [
      plugins.paths({
        // Determines where the root directory for front-end code is
        app: resolve(ROOT_PATH, 'app/ui'),
        // Determines where test setup should go for front-end code
        tests: resolve(ROOT_PATH, 'app/ui', 'tests'),
      }),


      // Sets up the app to get its assets from the default webpack endpoint in development.
      // You will need to change this to use your actual production cdn to get it working in production.
      // NOTE: If you are using dev and shopify-cloud gem you can delete this.
      plugins.cdn(
        env.isDevelopment ? 'http://localhost:8080/webpack/assets/' : undefined,
      ),

      // Sets up sewing-kit to generate type definitions for GraphQL using the given schema(s)
      // Uncomment the following if you are using GraphQL and make sure the path points to your generated schema
      // plugins.graphql({
      //   schema: resolve(__dirname, '..', 'app', 'graphql', 'schema.graphql'),
      // }),

      // Sets up sass mixins to be automatically imported.
      // Uncomment if you are using Polaris and want access to the sass mixins in your custom SCSS
      // plugins.sass({
      //   autoInclude: [
      //     path.join(
      //      __dirname,
      //      'node_modules/@shopify/polaris/dist/styles/_public-api.scss',
      //    ),
      //   ],
      // }),

      // configure additional sewing-kit plugins here
    ],
  };
}
