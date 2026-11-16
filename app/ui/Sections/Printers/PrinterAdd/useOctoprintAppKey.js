import { useCallback, useEffect, useRef, useState } from 'react'
import { useApolloClient, useSubscription } from '@apollo/client/react'

import { CANCEL_PRINTER_APP_KEY_REQUEST, PRINTER_APP_KEY_CHANGED, REQUEST_PRINTER_APP_KEY } from './graphql/add'

// OctoPrint gives up on a request after 10 minutes, and the server then pushes DENIED. Still waiting past this means
// a push was missed (a FAILED sent before the subscription started): stop waiting, as if it had expired.
export const WAIT_LIMIT = 11 * 60 * 1000

const openTab = (url) => { if (url) window.open(url, '_blank', 'noopener,noreferrer') }

// Browsers only allow a pop-up during a click, and the approval URL comes from the server after an await: so a click
// opens an empty tab right away, and the URL goes into it once the request has started. `noopener` would leave no
// handle to the tab: the link back to Tentacles is cut by hand instead. null when the browser blocked it anyway.
const openPlaceholder = () => {
  const tab = window.open('', '_blank')
  if (!tab) return null
  tab.opener = null
  try {
    tab.document.title = 'OctoPrint'
    tab.document.body.textContent = 'Waiting for OctoPrint…'
  } catch { /* only a courtesy */ }
  return tab
}

// The OctoPrint approval of one address found by the network scan. The server asks OctoPrint for an API key, polls
// it and adds the printer: this hook only starts the request, follows it on printerAppKeyChanged and never sees the
// key.
//
// connect({ withTab: true }) is for a click: it opens the approval tab during the click. Without it (a request
// started by ?connect=), no tab is opened: browsers block pop-ups that no click opened. `tabOpened` tells whether an
// approval tab was opened for the current request, by connect() or openApproval().
//
// `state`: null until connect(), then WAITING (only ever the mutation's answer), and the pushed ADDED (`onAdded` is
// called with the new printer), DENIED (refused or expired) or FAILED (`error`); CANCELLED after cancel().
// OctoPrint takes 3 requests a minute: requestPrinterAppKey is only sent by connect(), one request at a time.
// Unmounting while waiting cancels the request.
export default function useOctoprintAppKey (address, { onAdded } = {}) {
  const client = useApolloClient()
  const [request, setRequest] = useState(null) // { id, state, approvalUrl, printer, error }
  const [requesting, setRequesting] = useState(false)
  const [tabOpened, setTabOpened] = useState(false)
  const busy = useRef(false) // requesting or waiting: connect() does nothing
  const waitingId = useRef(null)
  const mounted = useRef(false)
  const added = useRef(onAdded)
  added.current = onAdded

  const sendCancel = useCallback((id) => {
    client.mutate({ mutation: CANCEL_PRINTER_APP_KEY_REQUEST, variables: { id } }).catch(() => {}) // over anyway
  }, [client])

  const finish = useCallback((update) => {
    busy.current = false
    waitingId.current = null
    setRequest(update)
    if (update.state === 'ADDED') added.current?.(update.printer)
  }, [])

  useSubscription(PRINTER_APP_KEY_CHANGED, {
    variables: { id: request?.id },
    skip: request?.state !== 'WAITING',
    onData: ({ data }) => {
      const update = data.data?.printerAppKeyChanged
      if (update && update.id === waitingId.current && update.state !== 'WAITING') finish(update)
    }
  })

  // The guard against a missed push: give up once OctoPrint has dropped the request
  useEffect(() => {
    if (request?.state !== 'WAITING') return
    const timer = setTimeout(() => {
      sendCancel(request.id)
      finish({ ...request, state: 'DENIED' })
    }, WAIT_LIMIT)
    return () => clearTimeout(timer)
  }, [request, sendCancel, finish])

  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
      if (waitingId.current) sendCancel(waitingId.current)
    }
  }, [sendCancel])

  const connect = useCallback(async ({ withTab = false } = {}) => {
    if (busy.current) return
    busy.current = true
    const tab = withTab ? openPlaceholder() : null // before any await: still in the click
    setTabOpened(false)
    setRequesting(true)
    try {
      const { data } = await client.mutate({ mutation: REQUEST_PRINTER_APP_KEY, variables: { address } })
      const { request: started, errors } = data.requestPrinterAppKey
      if (!started) {
        tab?.close()
        return finish({ address, state: 'FAILED', error: errors.join(' ') })
      }
      if (!mounted.current) { // left the page meanwhile
        tab?.close()
        return sendCancel(started.id)
      }

      waitingId.current = started.id
      setRequest(started)
      if (tab && !tab.closed && started.approvalUrl) {
        tab.location.href = started.approvalUrl
        setTabOpened(true)
      } else {
        tab?.close()
      }
    } catch (error) {
      tab?.close()
      finish({ address, state: 'FAILED', error: error.message })
    } finally {
      setRequesting(false)
    }
  }, [client, address, finish, sendCancel])

  const cancel = useCallback(() => {
    if (!waitingId.current) return
    sendCancel(waitingId.current)
    finish({ ...request, state: 'CANCELLED' })
  }, [request, sendCancel, finish])

  // Always from a click, which browsers allow. `noopener` leaves no handle to check the tab with.
  const openApproval = useCallback(() => {
    openTab(request?.approvalUrl)
    setTabOpened(true)
  }, [request])

  return {
    state: request?.state ?? null, error: request?.error ?? null, requesting, tabOpened, connect, cancel, openApproval
  }
}
