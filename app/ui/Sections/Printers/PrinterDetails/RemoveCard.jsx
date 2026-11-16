import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { useApolloClient } from '@apollo/client/react'
import { App, Button, Modal } from 'antd'

import { removeConfirmation } from '../PrintersList/RowMenu'
import { REMOVE_PRINTER } from '../PrintersList/graphql/fleet'
import * as classes from './PrinterDetails.module.less'

// Remove this printer: the fleet list's confirmation, then `onRemoved(id)` (the page leaves, then forgets it)
export default function RemoveCard ({ printer, onRemoved }) {
  const client = useApolloClient()
  const { message } = App.useApp()
  const [open, setOpen] = useState(false)
  const [removing, setRemoving] = useState(false)
  const confirmation = removeConfirmation(printer)

  const remove = async () => {
    if (removing) return
    setRemoving(true)
    try {
      const { data } = await client.mutate({ mutation: REMOVE_PRINTER, variables: { id: printer.id } })
      const { removedPrinterId, errors } = data.removePrinter
      errors.forEach((error) => message.error(error))
      if (removedPrinterId) return onRemoved(removedPrinterId)
    } catch (error) {
      message.error(`Remove Printer failed: ${error.message}`)
    }
    setRemoving(false)
    setOpen(false)
  }

  return (
    <section aria-labelledby="remove-title" className={classes.removeCard}>
      <div className={classes.removeText}>
        <h2 id="remove-title" className={classes.removeTitle}>Remove this printer</h2>
        <span className={classes.small}>
          Its queue and history are removed from Tentacles. The printer itself is not touched.
        </span>
      </div>
      <Button danger onClick={() => setOpen(true)}>Remove Printer</Button>
      <Modal open={open} title={confirmation.title} okText={confirmation.ok} cancelText={confirmation.keep}
        okButtonProps={{ danger: true }} confirmLoading={removing} onOk={remove}
        onCancel={() => !removing && setOpen(false)} centered width={400}>
        {confirmation.body}
      </Modal>
    </section>
  )
}

RemoveCard.propTypes = {
  printer: PropTypes.shape({ id: PropTypes.string.isRequired, name: PropTypes.string.isRequired }).isRequired,
  onRemoved: PropTypes.func.isRequired
}
