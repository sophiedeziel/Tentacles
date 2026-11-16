import React, { useRef, useState } from 'react'
import PropTypes from 'prop-types'
import { Link } from 'react-router'
import { useApolloClient } from '@apollo/client/react'
import { App, Button, Dropdown, Modal, Popconfirm } from 'antd'
import { MoreOutlined } from '@ant-design/icons'

import { ACTIONS } from '../../Dashboard/graphql/actions'
import confirmationFor from '../../Dashboard/widgets/Printer/confirmations'
import { REMOVE_PRINTER } from './graphql/fleet'

const LABELS = {
  details: 'Edit Details',
  pause: 'Pause Print',
  resume: 'Resume Print',
  cancel: 'Cancel Print',
  startNext: 'Start Next Print',
  connect: 'Connect',
  reconnect: 'Reconnect',
  remove: 'Remove Printer'
}

// Drops a removed printer from the cached list, then from the cache: a printQueueChanged push for it that comes
// later only makes an orphan entry, never a row
export function forgetPrinter (cache, id) {
  cache.modify({ fields: { printers: (refs, { readField }) => refs.filter((ref) => readField('id', ref) !== id) } })
  cache.evict({ id: cache.identify({ __typename: 'Printer', id }) })
  cache.gc()
}

async function removePrinter (client, printer) {
  const { data } = await client.mutate({
    mutation: REMOVE_PRINTER,
    variables: { id: printer.id },
    update: (cache, { data: result }) => {
      const id = result?.removePrinter?.removedPrinterId
      if (id) forgetPrinter(cache, id)
    }
  })
  return data.removePrinter.errors
}

// Runs a printer control or removes the printer, then shows what went wrong. The dashboard's mutations: the new
// state arrives through printerStatusChanged. `confirmed` is what the user confirmed (the file, the next job).
export function usePrinterAction () {
  const client = useApolloClient()
  const { message } = App.useApp()

  return async (key, printer, confirmed) => {
    try {
      let errors
      if (key === 'remove') {
        errors = await removePrinter(client, printer)
        if (errors.length === 0) message.success(`${printer.name} was removed`)
      } else {
        const { mutation, document } = ACTIONS[key]
        const { data } = await client.mutate({ mutation: document, variables: { printerId: printer.id, ...confirmed } })
        errors = data[mutation].errors
      }
      errors.forEach((error) => message.error(error))
    } catch (error) {
      message.error(`${LABELS[key]} failed: ${error.message}`)
    }
  }
}

// What the confirmations of the dashboard's controls read from a printer
const confirmationView = (printer, view) => ({
  name: printer.name,
  family: view.family,
  progress: Math.round(view.job?.progress ?? 0),
  headline: view.job?.fileName,
  nextJobName: printer.nextJob?.executable?.filename
})

// Also the details page's Remove Printer
export const removeConfirmation = (printer) => ({
  kind: 'modal',
  title: `Remove ${printer.name}?`,
  ok: 'Remove Printer',
  keep: 'Keep Printer',
  body: 'Its queue and history are removed from Tentacles, and its files stay in the library. The printer itself ' +
    'is not touched: a print under way keeps running.'
})

// The ⋯ menu of a fleet list row. Pause, Resume and Start Next confirm in a Popconfirm at the ⋯ button; Cancel and
// Remove in a modal; Reconnect runs at once (it doesn't touch a print). Like the dashboard's ControlButton, the
// confirmation's text and what OK sends (the file printing, the next job) are frozen when it opens: a push that
// changes the printer meanwhile makes the server refuse instead of acting on something the user didn't see.
export default function RowMenu ({ printer, view }) {
  const runAction = usePrinterAction()
  const busy = useRef(false)
  const [pending, setPending] = useState(null)
  const [running, setRunning] = useState(false)

  const close = () => !busy.current && setPending(null)
  const run = async () => {
    if (busy.current) return
    busy.current = true
    setRunning(true)
    await runAction(pending.key, printer, pending.confirmed)
    busy.current = false
    setRunning(false)
    setPending(null)
  }

  const onClick = ({ key }) => {
    if (key === 'reconnect') runAction(key, printer)
    else if (key === 'remove') setPending({ key, confirmation: removeConfirmation(printer) })
    else if (ACTIONS[key]) {
      const confirmation = confirmationFor(key, confirmationView(printer, view))
      setPending({ key, confirmation, confirmed: ACTIONS[key].expectations?.(printer) })
    }
  }

  const label = (key) => {
    if (key === 'details') return <Link to={`/printers/${printer.id}`}>{LABELS.details}</Link>
    if (key === 'openServer') {
      return <a href={printer.uri} target="_blank" rel="noopener noreferrer">Open {view.product}</a>
    }
    return LABELS[key]
  }
  const items = view.menu.flatMap((key) => [
    ...(key === 'remove' ? [{ type: 'divider' }] : []),
    { key, label: label(key), danger: key === 'remove' }
  ])
  const confirmation = pending?.confirmation

  return (
    <>
      <Popconfirm open={confirmation?.kind === 'popconfirm'} title={confirmation?.title}
        description={confirmation?.body} okText={confirmation?.ok} cancelText={confirmation?.keep}
        okButtonProps={{ loading: running }} placement="bottomRight" onConfirm={run} onCancel={close}
        onOpenChange={(open) => !open && close()}>
        <span>
          <Dropdown menu={{ items, onClick }} trigger={['click']} placement="bottomRight">
            <Button type="text" size="small" icon={<MoreOutlined rotate={90} />}
              aria-label={`More actions for ${printer.name}`} />
          </Dropdown>
        </span>
      </Popconfirm>
      <Modal open={confirmation?.kind === 'modal'} title={confirmation?.title} okText={confirmation?.ok}
        cancelText={confirmation?.keep} okButtonProps={{ danger: true }} confirmLoading={running} onOk={run}
        onCancel={close} centered width={400}>
        {confirmation?.body}
      </Modal>
    </>
  )
}

RowMenu.propTypes = {
  printer: PropTypes.shape({
    id: PropTypes.string.isRequired,
    name: PropTypes.string.isRequired,
    uri: PropTypes.string,
    nextJob: PropTypes.object
  }).isRequired,
  view: PropTypes.shape({
    family: PropTypes.string.isRequired,
    product: PropTypes.string.isRequired,
    job: PropTypes.object,
    menu: PropTypes.arrayOf(PropTypes.string).isRequired
  }).isRequired
}
