import React from 'react'
import AppLayout from '../AppLayout/AppLayout'

import AppSwitcher from '../AppSwitcher/AppSwitcher'

import { ApolloClient, HttpLink, InMemoryCache, ApolloLink } from '@apollo/client'
import { ApolloProvider } from '@apollo/client/react'
import UploadHttpLink from 'apollo-upload-client/UploadHttpLink.mjs'
import { createConsumer } from '@rails/actioncable'
import ActionCableLink from 'graphql-ruby-client/subscriptions/ActionCableLink'
import {
  BrowserRouter as Router
} from 'react-router'

import { setContext } from '@apollo/client/link/context'

const cable = createConsumer()

const authLink = setContext((_, { headers }) => {
  const csrfToken = document?.querySelector('meta[name=csrf-token]')?.getAttribute('content')

  return {
    headers: {
      ...headers,
      'X-CSRF-Token': csrfToken
    }
  }
})

const httpLink = ApolloLink.split(
  (operation) => operation.getContext().hasUpload,
  new UploadHttpLink({ uri: '/graphql' }),
  new HttpLink({ uri: '/graphql', credentials: 'include' })
)

const hasSubscriptionOperation = ({ query: { definitions } }) => {
  return definitions.some(
    ({ kind, operation }) => kind === 'OperationDefinition' && operation === 'subscription'
  )
}

const link = ApolloLink.split(
  hasSubscriptionOperation,
  new ActionCableLink({ cable }),
  authLink.concat(httpLink)
)

const client = new ApolloClient({
  link,
  cache: new InMemoryCache()
})

function App () {
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

export default App
