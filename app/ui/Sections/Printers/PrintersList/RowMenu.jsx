import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { Link } from 'react-router'
import { useApolloClient } from '@apollo/client/react'
import { App, Button, Dropdown, Modal } from 'antd'
import { MoreOutlined } from '@ant-design/icons'

import { ACTIONS } from '../../Dashboard/graphql/actions'
import { REMOVE_PRINTER } from './graphql/fleet'

const LABELS = {
  details: 'Edit Details',
  reconnect: 'Reconnect',
  remove: 'Remove Printer'
}

// Drops the removed printer from the cached list, then from the cache: a printQueueChanged push for it that comes
// later only makes an orphan entry, never a row
async function removePrinter (client, printer) {
  const { data } = await client.mutate({
    mutation: REMOVE_PRINTER,
    variables: { id: printer.id },
    update: (cache, { data: result }) => {
      const id = result?.removePrinter?.removedPrinterId
      if (!id) return
      cache.modify({ fields: { printers: (refs, { readField }) => refs.filter((ref) => readField('id', ref) !== id) } })
      cache.evict({ id: cache.identify({ __typename: 'Printer', id }) })
      cache.gc()
    }
  })
  return data.removePrinter.errors
}

// Runs a printer control (the dashboard's mutations: the new state arrives through printerStatusChanged) or removes
// the printer, then shows what went wrong
export function usePrinterAction () {
  const client = useApolloClient()
  const { message } = App.useApp()

  return async (key, printer) => {
    try {
      let errors
      if (key === 'remove') {
        errors = await removePrinter(client, printer)
        if (errors.length === 0) message.success(`${printer.name} was removed`)
      } else {
        const { mutation, document } = ACTIONS[key]
        const { data } = await client.mutate({ mutation: document, variables: { printerId: printer.id } })
        errors = data[mutation].errors
      }
      errors.forEach((error) => message.error(error))
    } catch (error) {
      message.error(`${LABELS[key]} failed: ${error.message}`)
    }
  }
}

// The ⋯ menu of a fleet list row. Reconnect runs at once (it doesn't touch a print); Remove asks in a modal first.
export default function RowMenu ({ printer, view }) {
  const runAction = usePrinterAction()
  const [removing, setRemoving] = useState(false)
  const [running, setRunning] = useState(false)

  const remove = async () => {
    if (running) return
    setRunning(true)
    await runAction('remove', printer)
    setRunning(false)
    setRemoving(false)
  }

  const onClick = ({ key }) => {
    if (key === 'reconnect') runAction(key, printer)
    if (key === 'remove') setRemoving(true)
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

  return (
    <>
      <Dropdown menu={{ items, onClick }} trigger={['click']} placement="bottomRight">
        <Button type="text" size="small" icon={<MoreOutlined rotate={90} />} aria-label={`More actions for ${printer.name}`} />
      </Dropdown>
      <Modal open={removing} title={`Remove ${printer.name}?`} okText="Remove Printer" cancelText="Keep Printer"
        okButtonProps={{ danger: true }} confirmLoading={running} onOk={remove} onCancel={() => !running && setRemoving(false)}
        centered width={400}>
        Its queue and history are removed from Tentacles, and its files stay in the library. The printer itself is not
        touched: a print under way keeps running.
      </Modal>
    </>
  )
}

RowMenu.propTypes = {
  printer: PropTypes.shape({
    id: PropTypes.string.isRequired,
    name: PropTypes.string.isRequired,
    uri: PropTypes.string
  }).isRequired,
  view: PropTypes.shape({
    product: PropTypes.string.isRequired,
    menu: PropTypes.arrayOf(PropTypes.string).isRequired
  }).isRequired
}
