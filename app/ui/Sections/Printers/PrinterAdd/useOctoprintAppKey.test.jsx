import React from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, renderHook, waitFor } from '@testing-library/react'
import { MockedProvider } from '@apollo/client/testing/react'

import useOctoprintAppKey, { WAIT_LIMIT } from './useOctoprintAppKey'
import { CANCEL_PRINTER_APP_KEY_REQUEST, PRINTER_APP_KEY_CHANGED, REQUEST_PRINTER_APP_KEY } from './graphql/add'

const ADDRESS = '192.168.1.57'
const APPROVAL_URL = `http://${ADDRESS}/plugin/appkeys/auth/token`
const appKeyRequest = (state, extra = {}) => ({
  __typename: 'AppKeyRequest', id: 'r1', address: ADDRESS, state, approvalUrl: APPROVAL_URL, error: null, printer: null, ...extra
})

// Counts what the server was sent
const mutation = (query, variables, payload) => {
  const sent = []
  return { sent, mock: { request: { query, variables }, result: () => { sent.push(variables); return { data: payload } }, maxUsageCount: 5 } }
}
const requestKey = (payload = { request: appKeyRequest('WAITING'), errors: [] }, delay = 0) => {
  const request = mutation(
    REQUEST_PRINTER_APP_KEY, { address: ADDRESS }, { requestPrinterAppKey: { __typename: 'RequestPrinterAppKeyPayload', ...payload } }
  )
  return { ...request, mock: { ...request.mock, delay } }
}
const failedRequest = { request: { query: REQUEST_PRINTER_APP_KEY, variables: { address: ADDRESS } }, error: new Error('Network down') }

// What window.open('', '_blank') hands back
const placeholderTab = () => ({
  opener: window, closed: false, close: vi.fn(), location: { href: 'about:blank' }, document: { title: '', body: { textContent: '' } }
})
const cancelKey = () => mutation(CANCEL_PRINTER_APP_KEY_REQUEST, { id: 'r1' }, {
  cancelPrinterAppKeyRequest: { __typename: 'CancelPrinterAppKeyRequestPayload', request: { __typename: 'AppKeyRequest', id: 'r1', state: 'CANCELLED' }, errors: [] }
})
const push = (request, delay = 20) => ({
  request: { query: PRINTER_APP_KEY_CHANGED, variables: { id: 'r1' } }, result: { data: { printerAppKeyChanged: request } }, delay
})
const never = push(appKeyRequest('DENIED'), 10 * WAIT_LIMIT)

const renderAppKey = (mocks, onAdded = vi.fn()) => {
  const wrapper = ({ children }) => <MockedProvider mocks={mocks}>{children}</MockedProvider>
  return { onAdded, ...renderHook(() => useOctoprintAppKey(ADDRESS, { onAdded }), { wrapper }) }
}

const connected = async (result, options) => {
  await act(() => result.current.connect(options))
  expect(result.current.state).toBe('WAITING')
}

describe('useOctoprintAppKey', () => {
  beforeEach(() => { vi.spyOn(window, 'open').mockReturnValue(null) })
  afterEach(() => {
    vi.restoreAllMocks()
    vi.useRealTimers()
  })

  it('asks the server for a key without opening a tab, then follows the request until ADDED', async () => {
    const printer = { __typename: 'Printer', id: '9', name: 'Ender 3 V2' }
    const { result, onAdded } = renderAppKey([requestKey().mock, push(appKeyRequest('ADDED', { printer }))])
    expect(result.current.state).toBeNull()

    await connected(result)
    expect(window.open).not.toHaveBeenCalled()
    expect(result.current.tabOpened).toBe(false)

    await waitFor(() => expect(result.current.state).toBe('ADDED'))
    expect(onAdded).toHaveBeenCalledWith(printer)
  })

  it('opens the tab during the click, before the server answers, and points it at the approval once the request started', async () => {
    const tab = placeholderTab()
    window.open.mockReturnValue(tab)
    const { result } = renderAppKey([requestKey(undefined, 50).mock, never])

    let connecting
    act(() => { connecting = result.current.connect({ withTab: true }) })
    expect(window.open).toHaveBeenCalledWith('', '_blank')
    expect(tab).toMatchObject({ opener: null, location: { href: 'about:blank' }, document: { body: { textContent: 'Waiting for OctoPrint…' } } })
    expect(result.current).toMatchObject({ requesting: true, state: null })

    await act(() => connecting)
    expect(result.current).toMatchObject({ state: 'WAITING', tabOpened: true })
    expect(tab.location.href).toBe(APPROVAL_URL)
    expect(tab.close).not.toHaveBeenCalled()
    expect(window.open).toHaveBeenCalledTimes(1)
  })

  it.each([
    ['OctoPrint could not be asked', () => requestKey({ request: null, errors: ['OctoPrint at http://192.168.1.57/ got too many requests.'] }).mock],
    ['the request failed', () => failedRequest]
  ])('closes the tab when %s', async (_, mock) => {
    const tab = placeholderTab()
    window.open.mockReturnValue(tab)
    const { result } = renderAppKey([mock()])
    await act(() => result.current.connect({ withTab: true }))
    expect(result.current).toMatchObject({ state: 'FAILED', tabOpened: false })
    expect(tab.close).toHaveBeenCalled()
    expect(tab.location.href).toBe('about:blank')
  })

  it('closes the tab when the page was left before the server answered', async () => {
    const tab = placeholderTab()
    window.open.mockReturnValue(tab)
    const cancel = cancelKey()
    const { result, unmount } = renderAppKey([requestKey(undefined, 20).mock, cancel.mock])
    let connecting
    act(() => { connecting = result.current.connect({ withTab: true }) })
    unmount()
    await connecting
    expect(tab.close).toHaveBeenCalled()
    expect(tab.location.href).toBe('about:blank')
    await waitFor(() => expect(cancel.sent).toEqual([{ id: 'r1' }]))
  })

  it('waits without a tab when the browser blocked it', async () => {
    const { result } = renderAppKey([requestKey().mock, never])
    await connected(result, { withTab: true })
    expect(window.open).toHaveBeenCalledWith('', '_blank')
    expect(result.current.tabOpened).toBe(false)
  })

  it('opens the approval page from a click', async () => {
    const { result } = renderAppKey([requestKey().mock, never])
    await connected(result)
    act(() => result.current.openApproval())
    expect(window.open).toHaveBeenCalledWith(APPROVAL_URL, '_blank', 'noopener,noreferrer')
    expect(result.current.tabOpened).toBe(true)
  })

  it.each([
    ['DENIED', null],
    ['FAILED', 'Could not reach OctoPrint at http://192.168.1.57/']
  ])('shows a pushed %s', async (state, error) => {
    const { result, onAdded } = renderAppKey([requestKey().mock, push(appKeyRequest(state, { error }))])
    await connected(result)
    await waitFor(() => expect(result.current.state).toBe(state))
    expect(result.current.error).toBe(error)
    expect(onAdded).not.toHaveBeenCalled()
  })

  it('fails when OctoPrint could not be asked, without opening a tab', async () => {
    const tooMany = 'OctoPrint at http://192.168.1.57/ got too many requests. Try again in a minute.'
    const { result } = renderAppKey([requestKey({ request: null, errors: [tooMany] }).mock])
    await act(() => result.current.connect())
    expect(result.current).toMatchObject({ state: 'FAILED', error: tooMany })
    expect(window.open).not.toHaveBeenCalled()
  })

  it('cancels the request on the server', async () => {
    const cancel = cancelKey()
    const { result } = renderAppKey([requestKey().mock, never, cancel.mock])
    await connected(result)
    act(() => result.current.cancel())
    expect(result.current.state).toBe('CANCELLED')
    await waitFor(() => expect(cancel.sent).toEqual([{ id: 'r1' }]))
  })

  it('cancels the request when unmounted while waiting', async () => {
    const cancel = cancelKey()
    const { result, unmount } = renderAppKey([requestKey().mock, never, cancel.mock])
    await connected(result)
    unmount()
    await waitFor(() => expect(cancel.sent).toEqual([{ id: 'r1' }]))
  })

  it('sends one request at a time, and never on render', async () => {
    const request = requestKey()
    const { result, rerender } = renderAppKey([request.mock, never])
    rerender()
    expect(request.sent).toEqual([])

    await act(() => Promise.all([result.current.connect(), result.current.connect()]))
    await act(() => result.current.connect())
    rerender()
    expect(request.sent).toHaveLength(1)
  })

  it('stops waiting once OctoPrint has dropped the request, in case a push was missed', async () => {
    vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'], shouldAdvanceTime: true })
    const cancel = cancelKey()
    const { result } = renderAppKey([requestKey().mock, never, cancel.mock])
    await connected(result)
    act(() => vi.advanceTimersByTime(WAIT_LIMIT))
    expect(result.current.state).toBe('DENIED')
    await waitFor(() => expect(cancel.sent).toEqual([{ id: 'r1' }]))
  })
})
