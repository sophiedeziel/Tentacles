import React from 'react'
import PropTypes from 'prop-types'
import { App, Button, Dropdown } from 'antd'
import { MoreOutlined } from '@ant-design/icons'

import { cancelConfirmation, removeConfirmation } from './confirmations'

// The "⋯" menus of the Waiting and Printing rows (antd Dropdown). Each entry runs one of useQueueActions' actions;
// Remove and Cancel Print ask first, in a plain Modal.confirm.

const isBound = (job) => job.samePrinter && !!job.boundPrinter

// Asks in a Modal.confirm, then runs `action`: the modal stays open (OK loading) until it's done
function useConfirm () {
  const { modal } = App.useApp()
  return ({ title, body, ok, keep }, action) => modal.confirm({
    title,
    content: body,
    okText: ok,
    cancelText: keep,
    okButtonProps: { danger: true },
    centered: true,
    onOk: action
  })
}

function MoreMenu ({ label, items, onClick }) {
  return (
    <Dropdown menu={{ items, onClick }} trigger={['click']} placement="bottomRight">
      <Button type="text" size="small" icon={<MoreOutlined rotate={90} />} aria-label={label} />
    </Dropdown>
  )
}

// A waiting job: Move to Top / Bottom, Hold or Release, Release to Other Printers (a same-printer batch bound to its
// printer), Remove from Queue (its waiting copies, after a confirmation). `rank` and `count`: where it is in the queue.
export function WaitingMenu ({ job, rank, count, actions }) {
  const confirm = useConfirm()
  const items = [
    { key: 'top', label: 'Move to Top', disabled: rank === 1 },
    { key: 'bottom', label: 'Move to Bottom', disabled: rank === count },
    job.held ? { key: 'release', label: 'Release' } : { key: 'hold', label: 'Hold' },
    isBound(job) && { key: 'unbind', label: 'Release to Other Printers' },
    { type: 'divider' },
    { key: 'remove', label: 'Remove from Queue', danger: true }
  ].filter(Boolean)

  const onClick = ({ key }) => {
    if (key === 'top') actions.move(job, { to: 'TOP' })
    else if (key === 'bottom') actions.move(job, { to: 'BOTTOM' })
    else if (key === 'remove') confirm(removeConfirmation(job), () => actions.remove(job))
    else actions[key](job)
  }

  return <MoreMenu label={`More actions for ${job.file.filename}`} items={items} onClick={onClick} />
}

// The controls a printer's live state allows: Pause while printing, Resume while paused, Cancel Print in both
const printControls = (family) => [
  family === 'PRINTING' && { key: 'pausePrint', label: 'Pause Print' },
  family === 'PAUSED' && { key: 'resumePrint', label: 'Resume Print' },
  ['PRINTING', 'PAUSED'].includes(family) && { key: 'cancelPrint', label: 'Cancel Print', danger: true }
].filter(Boolean)

// What can be done to the rest of a copy's job while it still has copies waiting (`job`, its Waiting row)
const restOfJob = (job) => (job
  ? [
      job.held ? { key: 'release', label: 'Release the Rest' } : { key: 'hold', label: 'Hold the Rest' },
      isBound(job) && { key: 'unbind', label: 'Release to Other Printers' },
      { key: 'remove', label: 'Remove the Waiting Copies', danger: true }
    ].filter(Boolean)
  : [])

// A copy printing: Pause, Resume and Cancel Print (from its printer's live status), then the waiting job's options
// when its job still has copies waiting (`job`). Cancel Print sends the file shown on the row as expectedFileName.
export function PrintingMenu ({ print, job, actions }) {
  const confirm = useConfirm()
  const controls = printControls(print.printer.status?.stateFamily)
  const rest = restOfJob(job)
  const items = [...controls, ...(controls.length && rest.length ? [{ type: 'divider' }] : []), ...rest]
  if (items.length === 0) return null

  const onClick = ({ key }) => {
    if (key === 'cancelPrint') confirm(cancelConfirmation(print), () => actions.cancelPrint(print))
    else if (key === 'pausePrint' || key === 'resumePrint') actions[key](print)
    else if (key === 'remove') confirm(removeConfirmation(job), () => actions.remove(job))
    else actions[key](job)
  }

  const copy = print.printJob.copies > 1 ? ` copy ${print.copyNumber}` : ''
  return <MoreMenu label={`More actions for ${print.printJob.file.filename}${copy}`} items={items} onClick={onClick} />
}

const actionsShape = PropTypes.shape({
  move: PropTypes.func.isRequired,
  hold: PropTypes.func.isRequired,
  release: PropTypes.func.isRequired,
  unbind: PropTypes.func.isRequired,
  remove: PropTypes.func.isRequired,
  pausePrint: PropTypes.func,
  resumePrint: PropTypes.func,
  cancelPrint: PropTypes.func,
  setCopies: PropTypes.func,
  requeue: PropTypes.func
})

MoreMenu.propTypes = {
  label: PropTypes.string.isRequired,
  items: PropTypes.arrayOf(PropTypes.object).isRequired,
  onClick: PropTypes.func.isRequired
}
WaitingMenu.propTypes = {
  job: PropTypes.object.isRequired,
  rank: PropTypes.number.isRequired,
  count: PropTypes.number.isRequired,
  actions: actionsShape.isRequired
}
PrintingMenu.propTypes = { print: PropTypes.object.isRequired, job: PropTypes.object, actions: actionsShape.isRequired }

export { actionsShape }
