import React from 'react'
import { describe, expect, it } from 'vitest'
import { act, renderHook, waitFor } from '@testing-library/react'
import { ApolloClient, ApolloLink, InMemoryCache } from '@apollo/client'
import { ApolloProvider } from '@apollo/client/react'
import { Observable } from 'rxjs'

import useGlobalQueue, { REFETCH_DELAY } from './useGlobalQueue'
import { POSSIBLE_TYPES, TYPE_POLICIES } from '../Dashboard/graphql/dashboard'
import { EMPTY_QUEUE } from './fixtures'

// A server that counts the page's requests and pushes queueChanged when told to. The other subscriptions never push.
function fakeServer () {
  const server = { pageRequests: 0, push: null }
  server.link = new ApolloLink((operation) => new Observable((observer) => {
    if (operation.operationName === 'GlobalQueuePage') {
      server.pageRequests += 1
      observer.next({ data: { globalQueue: EMPTY_QUEUE } })
      observer.complete()
    } else if (operation.operationName === 'GlobalQueueChanged') {
      server.push = () => observer.next({
        data: { queueChanged: { __typename: 'QueueChange', dispatchPaused: false } }
      })
    }
  }))
  return server
}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

describe('useGlobalQueue', () => {
  it('loads the queue, then reloads it once per burst of queueChanged pushes', async () => {
    const server = fakeServer()
    const client = new ApolloClient({
      link: server.link,
      cache: new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })
    })
    const { result } = renderHook(() => useGlobalQueue(), {
      wrapper: ({ children }) => <ApolloProvider client={client}>{children}</ApolloProvider>
    })

    await waitFor(() => expect(result.current.loaded).toBe(true))
    await waitFor(() => expect(server.push).not.toBeNull())
    expect(result.current.queue.dispatchPaused).toBe(false)
    expect(server.pageRequests).toBe(1)

    act(() => {
      server.push()
      server.push()
      server.push()
    })
    await wait(REFETCH_DELAY / 2)
    expect(server.pageRequests).toBe(1)

    await waitFor(() => expect(server.pageRequests).toBe(2))
    await wait(REFETCH_DELAY * 2)
    expect(server.pageRequests).toBe(2)
  })
})

describe('useGlobalQueue while holding', () => {
  // A server whose queue says dispatch is paused once `paused` is set
  function changingServer () {
    const server = { paused: false, requests: 0 }
    server.link = new ApolloLink((operation) => new Observable((observer) => {
      if (operation.operationName !== 'GlobalQueuePage') return
      server.requests += 1
      observer.next({ data: { globalQueue: { ...EMPTY_QUEUE, dispatchPaused: server.paused } } })
      observer.complete()
    }))
    return server
  }

  it('keeps what it showed while holding, then shows the latest answer', async () => {
    const server = changingServer()
    const client = new ApolloClient({
      link: server.link,
      cache: new InMemoryCache({ possibleTypes: POSSIBLE_TYPES, typePolicies: TYPE_POLICIES })
    })
    const { result, rerender } = renderHook(({ holding }) => useGlobalQueue({ holding }), {
      initialProps: { holding: false },
      wrapper: ({ children }) => <ApolloProvider client={client}>{children}</ApolloProvider>
    })
    await waitFor(() => expect(result.current.loaded).toBe(true))
    const before = result.current.queue

    rerender({ holding: true })
    server.paused = true
    await act(() => result.current.reload())
    expect(server.requests).toBe(2)
    expect(result.current.queue).toBe(before)
    expect(result.current.queue.dispatchPaused).toBe(false)

    rerender({ holding: false })
    expect(result.current.queue.dispatchPaused).toBe(true)
  })
})
