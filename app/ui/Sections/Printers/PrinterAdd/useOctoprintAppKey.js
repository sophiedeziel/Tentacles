import { useCallback, useEffect, useRef, useState } from 'react'
import { useApolloClient, useSubscription } from '@apollo/client/react'

import { CANCEL_PRINTER_APP_KEY_REQUEST, PRINTER_APP_KEY_CHANGED, REQUEST_PRINTER_APP_KEY } from './graphql/add'

// OctoPrint gives up on a request after 10 minutes, and the server then pushes DENIED. Still waiting past this means
// a push was missed (a FAILED sent before the subscription started): stop waiting, as if it had expired.
export const WAIT_LIMIT = 11 * 60 * 1000

const openTab = (url) => { if (url) window.open(url, '_blank', 'noopener,noreferrer') }

// The OctoPrint approval of one address found by the network scan. The server asks OctoPrint for an API key, polls
// it and adds the printer: this hook only starts the request, follows it on printerAppKeyChanged and never sees the
// key.
//
// `state`: null until connect(), then WAITING (only ever the mutation's answer), and the pushed ADDED (`onAdded` is
// called with the new printer), DENIED (refused or expired) or FAILED (`error`); CANCELLED after cancel().
// OctoPrint takes 3 requests a minute: requestPrinterAppKey is only sent by connect(), one request at a time.
// Unmounting while waiting cancels the request.
export default function useOctoprintAppKey (address, { onAdded } = {}) {
  const client = useApolloClient()
  const [request, setRequest] = useState(null) // { id, state, approvalUrl, printer, error }
  const [requesting, setRequesting] = useState(false)
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

  const connect = useCallback(async () => {
    if (busy.current) return
    busy.current = true
    setRequesting(true)
    try {
      const { data } = await client.mutate({ mutation: REQUEST_PRINTER_APP_KEY, variables: { address } })
      const { request: started, errors } = data.requestPrinterAppKey
      if (!started) return finish({ address, state: 'FAILED', error: errors.join(' ') })
      if (!mounted.current) return sendCancel(started.id) // left the page meanwhile

      waitingId.current = started.id
      setRequest(started)
      openTab(started.approvalUrl)
    } catch (error) {
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

  const openApproval = useCallback(() => openTab(request?.approvalUrl), [request])

  return { state: request?.state ?? null, error: request?.error ?? null, requesting, connect, cancel, openApproval }
}
