import React from 'react'
import PropTypes from 'prop-types'
import { useNavigate } from 'react-router'
import { App, Button, Dropdown } from 'antd'
import {
  ArrowDownOutlined, ArrowUpOutlined, DeleteOutlined, EllipsisOutlined, PauseCircleOutlined, PlayCircleOutlined,
  PlusOutlined, StopOutlined, UndoOutlined, UnorderedListOutlined
} from '@ant-design/icons'

import { GcodeFileOutlined, Printer3DOutlined, PrintQueueOutlined } from '../../components/icons'
import { cancelConfirmation, removeConfirmation } from './confirmations'

// The "⋯" menus of the Waiting and Printing rows (antd Dropdown), as the MoreMenu frame draws them (without Open
// Project and Edit Printers and Options, which come with projects and the Add to Queue screen). Each entry runs one
// of useQueueActions' actions, opens the copies dialog, shows a batch or opens a page; Remove from Queue and Cancel
// Print ask first, in a plain Modal.confirm.

const DIVIDER = { type: 'divider' }
const isBound = (job) => job.samePrinter && !!job.boundPrinter
const item = (key, label, Icon, extra = {}) => ({ key, label, icon: <Icon aria-hidden />, ...extra })

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
    <Dropdown menu={{ items, onClick, style: { minWidth: 232 } }} trigger={['click']} placement="bottomRight">
      <Button type="text" size="small" icon={<EllipsisOutlined />} aria-label={label} />
    </Dropdown>
  )
}

// A waiting job: Move to Top / Bottom, Hold or Release | Change Number of Copies and Show Copies (a batch) or Print
// More Copies (a single print), Release to Other Printers (a bound same-printer batch) | Open File | Remove from Queue.
// `rank` and `count`: where it is in the queue. `onCopies(job)`: the copies dialog; `onShow(job)`: expands its copies.
export function WaitingMenu ({ job, rank, count, actions, onCopies, onShow }) {
  const confirm = useConfirm()
  const navigate = useNavigate()
  const batch = job.copies > 1
  const items = [
    item('top', 'Move to Top', ArrowUpOutlined, { disabled: rank === 1 }),
    item('bottom', 'Move to Bottom', ArrowDownOutlined, { disabled: rank === count }),
    job.held ? item('release', 'Release', PlayCircleOutlined) : item('hold', 'Hold', PauseCircleOutlined),
    DIVIDER,
    ...(batch
      ? [item('copies', 'Change Number of Copies', PlusOutlined), item('show', 'Show Copies', UnorderedListOutlined)]
      : [item('copies', 'Print More Copies', PlusOutlined)]),
    isBound(job) && item('unbind', 'Release to Other Printers', UndoOutlined),
    DIVIDER,
    item('file', 'Open File', GcodeFileOutlined, { disabled: job.file.isDeleted }),
    DIVIDER,
    item('remove', 'Remove from Queue', DeleteOutlined, { danger: true })
  ].filter(Boolean)

  const onClick = ({ key }) => {
    if (key === 'top') actions.move(job, { to: 'TOP' })
    else if (key === 'bottom') actions.move(job, { to: 'BOTTOM' })
    else if (key === 'copies') onCopies(job)
    else if (key === 'show') onShow(job)
    else if (key === 'file') navigate(`/files/${job.file.id}`)
    else if (key === 'remove') confirm(removeConfirmation(job), () => actions.remove(job))
    else actions[key](job)
  }

  return <MoreMenu label={`More actions for ${job.file.filename}`} items={items} onClick={onClick} />
}

// A copy printing: Pause Print or Resume Print (from its printer's live status) | Change Number of Copies and Show
// Batch in Waiting (a batch with copies waiting) or Print More Copies (a single print) | Open File, Open Printer |
// Cancel Print. Cancel Print sends the file shown on the row as expectedFileName. `onCopies(job)` opens the copies
// dialog for its print job; `onShow(job)` shows its Waiting row.
export function PrintingMenu ({ print, actions, onCopies, onShow }) {
  const confirm = useConfirm()
  const navigate = useNavigate()
  const family = print.printer.status?.stateFamily
  const job = print.printJob
  const batch = job.copies > 1
  const control = [
    family === 'PRINTING' && item('pausePrint', 'Pause Print', PauseCircleOutlined),
    family === 'PAUSED' && item('resumePrint', 'Resume Print', PlayCircleOutlined)
  ].filter(Boolean)
  const items = [
    ...control,
    control.length > 0 && DIVIDER,
    ...(batch
      ? [
          item('copies', 'Change Number of Copies', PlusOutlined),
          job.copiesLeftToStart > 0 && item('show', 'Show Batch in Waiting', PrintQueueOutlined)
        ]
      : [item('copies', 'Print More Copies', PlusOutlined)]),
    DIVIDER,
    item('file', 'Open File', GcodeFileOutlined, { disabled: job.file.isDeleted }),
    item('printer', 'Open Printer', Printer3DOutlined),
    ...(['PRINTING', 'PAUSED'].includes(family)
      ? [DIVIDER, item('cancelPrint', 'Cancel Print', StopOutlined, { danger: true })]
      : [])
  ].filter(Boolean)

  const onClick = ({ key }) => {
    if (key === 'cancelPrint') confirm(cancelConfirmation(print), () => actions.cancelPrint(print))
    else if (key === 'copies') onCopies(job)
    else if (key === 'show') onShow(job)
    else if (key === 'file') navigate(`/files/${job.file.id}`)
    else if (key === 'printer') navigate(`/printers/${print.printer.id}`)
    else actions[key](print)
  }

  const copy = batch ? ` copy ${print.copyNumber}` : ''
  return <MoreMenu label={`More actions for ${job.file.filename}${copy}`} items={items} onClick={onClick} />
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
  requeue: PropTypes.func,
  reconnect: PropTypes.func
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
  actions: actionsShape.isRequired,
  onCopies: PropTypes.func.isRequired,
  onShow: PropTypes.func.isRequired
}
PrintingMenu.propTypes = {
  print: PropTypes.object.isRequired,
  actions: actionsShape.isRequired,
  onCopies: PropTypes.func.isRequired,
  onShow: PropTypes.func.isRequired
}

export { actionsShape }
