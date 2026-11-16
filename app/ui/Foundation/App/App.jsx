import React from 'react'
import AppLayout from '../AppLayout/AppLayout'

import AppSwitcher from '../AppSwitcher/AppSwitcher'

import { ApolloClient, HttpLink, InMemoryCache, ApolloLink } from '@apollo/client'
import { ApolloProvider } from '@apollo/client/react'
import UploadHttpLink from 'apollo-upload-client/UploadHttpLink.mjs'
import { createConsumer } from '@rails/actioncable'
import ActionCableLink from 'graphql-ruby-client/subscriptions/ActionCableLink'
import { createBrowserRouter } from 'react-router'
import { RouterProvider } from 'react-router/dom'

import { setContext } from '@apollo/client/link/context'
import { POSSIBLE_TYPES, TYPE_POLICIES } from '../../Sections/Dashboard/graphql/dashboard'

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
  cache: new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })
})

// A data router, for useBlocker (the printer details page's unsaved-changes guard). AppSwitcher's <Routes> still
// pick the page under it.
const router = createBrowserRouter([
  { path: '*', element: <AppLayout><AppSwitcher /></AppLayout> }
])

function App () {
  return (
    <ApolloProvider client={client}>
      <RouterProvider router={router} />
    </ApolloProvider>
  )
}

export default App
