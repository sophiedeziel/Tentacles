import React, { useRef, useState } from 'react'
import PropTypes from 'prop-types'
import { App, Button, Modal, Popconfirm } from 'antd'

import confirmationFor from './confirmations'

// One printer control. It confirms first when the control changes a print, then runs `onRun` (which resolves to
// the mutation's errors) with a spinner on the button, and shows the errors it returns. A control runs once at a
// time: double clicks and a second OK while the first runs are ignored. `live` is false when the dashboard may show
// stale states; the confirmation says so. `size` and `placement` set the button's size and the Popconfirm's side.
export default function ControlButton ({ action, view, onRun, live = true, size, placement = 'topLeft' }) {
  const { message } = App.useApp()
  const busy = useRef(false)
  const [running, setRunning] = useState(false)
  const [modalOpen, setModalOpen] = useState(false)
  const confirmation = confirmationFor(action.key, view, live)

  const run = async () => {
    if (busy.current) return
    busy.current = true
    setRunning(true)
    try {
      const errors = await onRun(action.key)
      errors.forEach((error) => message.error(error))
    } catch (error) {
      message.error(`${action.label} failed: ${error.message}`)
    } finally {
      busy.current = false
      setRunning(false)
      setModalOpen(false)
    }
  }

  const button = (onClick) => (
    <Button danger={action.danger} disabled={action.disabled} loading={action.loading || running} onClick={onClick}
      size={size}>
      {action.label}
    </Button>
  )

  if (action.disabled) return button()
  if (confirmation?.kind === 'popconfirm') {
    return (
      <Popconfirm title={confirmation.title} description={confirmation.body} okText={confirmation.ok}
        cancelText={confirmation.keep} placement={placement} onConfirm={run} disabled={running}>
        {button()}
      </Popconfirm>
    )
  }
  if (confirmation?.kind === 'modal') {
    return (
      <>
        {button(() => setModalOpen(true))}
        <Modal open={modalOpen} title={confirmation.title} okText={confirmation.ok} cancelText={confirmation.keep}
          okButtonProps={{ danger: true }} confirmLoading={running} onOk={run}
          onCancel={() => !busy.current && setModalOpen(false)} centered width={400}>
          {confirmation.body}
        </Modal>
      </>
    )
  }
  return button(run)
}

ControlButton.propTypes = {
  action: PropTypes.shape({
    key: PropTypes.string.isRequired,
    label: PropTypes.string.isRequired,
    danger: PropTypes.bool,
    disabled: PropTypes.bool,
    loading: PropTypes.bool
  }).isRequired,
  view: PropTypes.object.isRequired,
  onRun: PropTypes.func.isRequired,
  live: PropTypes.bool,
  size: PropTypes.oneOf(['small', 'middle', 'large']),
  placement: PropTypes.string
}
