import React from 'react'
import PropTypes from 'prop-types'
import { Button, Input } from 'antd'
import { DownOutlined, HolderOutlined, UpOutlined } from '@ant-design/icons'

import * as classes from './Section.module.less'

// As DashboardSection validates it
const MAX_TITLE_LENGTH = 100

// A divider in edit mode: its drag handle, its editable title, ▲ ▼ to move it (with its widgets) and Remove
// Divider, which hands its widgets to the section above. The first divider can't move above the untitled section.
export default function DividerRow ({ section, index, count, dispatch, handle = null }) {
  const { key } = section
  return (
    <div className={classes.dividerEdit}>
      {handle || <span className={classes.handle}><HolderOutlined /></span>}
      <Input value={section.title ?? ''} maxLength={MAX_TITLE_LENGTH} aria-label="Section name"
        placeholder="Section name" className={classes.titleInput} status={section.title?.trim() ? undefined : 'error'}
        onChange={(event) => dispatch({ type: 'renameDivider', key, title: event.target.value })} />
      <span className={classes.dividerLine} />
      <Button aria-label="Move divider earlier" icon={<UpOutlined />} disabled={index <= 1}
        onClick={() => dispatch({ type: 'stepDivider', key, step: -1 })} />
      <Button aria-label="Move divider later" icon={<DownOutlined />} disabled={index >= count - 1}
        onClick={() => dispatch({ type: 'stepDivider', key, step: 1 })} />
      <Button danger onClick={() => dispatch({ type: 'removeDivider', key })}>Remove Divider</Button>
    </div>
  )
}

DividerRow.propTypes = {
  section: PropTypes.shape({ key: PropTypes.string.isRequired, title: PropTypes.string }).isRequired,
  index: PropTypes.number.isRequired,
  count: PropTypes.number.isRequired,
  dispatch: PropTypes.func.isRequired,
  handle: PropTypes.node
}
