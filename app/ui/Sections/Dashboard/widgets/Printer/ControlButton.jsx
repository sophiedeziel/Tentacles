import React, { useRef, useState } from 'react'
import PropTypes from 'prop-types'
import { App, Button, Modal, Popconfirm } from 'antd'

import confirmationFor from './confirmations'

// One printer control. It confirms first when the control changes a print, then runs `onRun` (which resolves to
// the mutation's errors) with a spinner on the button, and shows the errors it returns. A control runs once at a
// time: double clicks and a second OK while the first runs are ignored. `live` is false when the dashboard may show
// stale states; the confirmation says so. `size` and `placement` set the button's size and the Popconfirm's side.
//
// `snapshot()` returns what the user confirms (the file printing, the next job), passed on to `onRun(key, confirmed)`.
// It is taken when the confirmation opens, and the confirmation's text is frozen then too: a push that changes the
// printer while it is open can't change what OK runs, so the server refuses instead of acting on something unseen.
export default function ControlButton ({ action, view, onRun, live = true, size, placement = 'topLeft', snapshot }) {
  const { message } = App.useApp()
  const busy = useRef(false)
  const [running, setRunning] = useState(false)
  const [modalOpen, setModalOpen] = useState(false)
  const [opened, setOpened] = useState(null)
  const confirmation = opened?.confirmation ?? confirmationFor(action.key, view, live)

  const open = () => setOpened({ confirmation: confirmationFor(action.key, view, live), confirmed: snapshot?.() })
  const close = () => {
    setModalOpen(false)
    setOpened(null)
  }

  const run = async () => {
    if (busy.current) return
    const confirmed = opened ? opened.confirmed : snapshot?.()
    busy.current = true
    setRunning(true)
    try {
      const errors = await onRun(action.key, confirmed)
      errors.forEach((error) => message.error(error))
    } catch (error) {
      message.error(`${action.label} failed: ${error.message}`)
    } finally {
      busy.current = false
      setRunning(false)
      close()
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
        cancelText={confirmation.keep} placement={placement} onConfirm={run} disabled={running}
        onOpenChange={(isOpen) => (isOpen ? open() : !busy.current && close())}>
        {button()}
      </Popconfirm>
    )
  }
  if (confirmation?.kind === 'modal') {
    return (
      <>
        {button(() => {
          open()
          setModalOpen(true)
        })}
        <Modal open={modalOpen} title={confirmation.title} okText={confirmation.ok} cancelText={confirmation.keep}
          okButtonProps={{ danger: true }} confirmLoading={running} onOk={run}
          onCancel={() => !busy.current && close()} centered width={400}>
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
  placement: PropTypes.string,
  snapshot: PropTypes.func
}
