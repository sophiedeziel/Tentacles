import React from 'react';
import AppLayout from '../AppLayout/AppLayout'

import AppSwitcher from '../AppSwitcher/AppSwitcher'

import { ApolloClient, HttpLink, InMemoryCache, ApolloProvider } from '@apollo/client';
import {
  BrowserRouter as Router,
} from "react-router-dom";

import { setContext } from "@apollo/client/link/context";

const authLink = setContext((_, { headers }) => {
  const csrfToken = document?.querySelector("meta[name=csrf-token]")?.getAttribute("content");

  return {
    headers: {
      ...headers,
      "X-CSRF-Token": csrfToken,
    },
  };
});

const client = new ApolloClient({
  link: authLink.concat(new HttpLink({ uri: "/graphql" })),
  cache: new InMemoryCache(),
});

function App() {
  return (
    <ApolloProvider client={client}>
      <Router>
        <AppLayout>
          <AppSwitcher />
        </AppLayout>
      </Router>
    </ApolloProvider>
  )
}

export default App;
