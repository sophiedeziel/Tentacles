import React from 'react'
import PropTypes from 'prop-types'
import { Button } from 'antd'
import { EditOutlined, PlusOutlined } from '@ant-design/icons'

import * as classes from './EditBar.module.less'

// Three lines, as in the mockup
function DividerIcon () {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"
      strokeLinecap="round" aria-hidden="true">
      <path d="M3 12h18M7 7h10M7 17h10" />
    </svg>
  )
}

// The page header's buttons: Edit Dashboard in view mode; Reset Layout, Add Divider, Add Widget and Done in edit
// mode. `busy` is the edit-mode action running ('reset' or 'save'), which disables the others.
export default function EditBar ({ editing, busy = null, onEdit, onReset, onAddDivider, onAddWidget, onDone }) {
  if (!editing) {
    return <Button icon={<EditOutlined />} onClick={onEdit} disabled={!onEdit}>Edit Dashboard</Button>
  }

  return (
    <div className={classes.bar}>
      <Button type="text" onClick={onReset} loading={busy === 'reset'} disabled={!!busy && busy !== 'reset'}>
        Reset Layout
      </Button>
      <Button icon={<DividerIcon />} onClick={onAddDivider} disabled={!!busy}>Add Divider</Button>
      {onAddWidget && (
        <Button type="dashed" icon={<PlusOutlined />} onClick={onAddWidget} disabled={!!busy}>Add Widget</Button>
      )}
      <Button type="primary" onClick={onDone} loading={busy === 'save'} disabled={!!busy && busy !== 'save'}>
        Done
      </Button>
    </div>
  )
}

EditBar.propTypes = {
  editing: PropTypes.bool.isRequired,
  busy: PropTypes.oneOf(['reset', 'save']),
  onEdit: PropTypes.func,
  onReset: PropTypes.func,
  onAddDivider: PropTypes.func,
  onAddWidget: PropTypes.func,
  onDone: PropTypes.func
}

// Under the header while editing
export function EditNotice () {
  return (
    <p className={classes.notice}>
      Drag a widget and the dashboard rearranges as you move, so you see the result before you let go (Esc cancels).
      Dividers start a new row: widgets never flow across them. Pick S, M or L to resize.
    </p>
  )
}
