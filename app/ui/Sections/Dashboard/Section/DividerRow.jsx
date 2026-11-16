import React from 'react'
import PropTypes from 'prop-types'
import { Button, Input } from 'antd'
import { DownOutlined, HolderOutlined, UpOutlined } from '@ant-design/icons'

import * as classes from './Section.module.less'

// As DashboardSection validates it
const MAX_TITLE_LENGTH = 100

// The title and the buttons work as usual: pressing them never picks the divider up
const stop = (event) => event.stopPropagation()
const OWN_PRESS = { onMouseDown: stop, onTouchStart: stop }

// A divider in edit mode: its drag handle, its editable title, ▲ ▼ to move it (with its widgets) and Remove
// Divider, which hands its widgets to the section above. The first divider can't move above the untitled section.
// `dragListeners` let the rest of the bar drag the divider too.
export default function DividerRow ({ section, index, count, dispatch, handle = null, dragListeners = null }) {
  const { key } = section
  return (
    <div className={dragListeners ? classes.dividerDrag : classes.dividerEdit} {...dragListeners}>
      {handle || <span className={classes.handle}><HolderOutlined /></span>}
      <Input {...OWN_PRESS} value={section.title ?? ''} maxLength={MAX_TITLE_LENGTH} aria-label="Section name"
        placeholder="Section name" className={classes.titleInput} status={section.title?.trim() ? undefined : 'error'}
        onChange={(event) => dispatch({ type: 'renameDivider', key, title: event.target.value })} />
      <span className={classes.dividerLine} />
      {/* On the wrapper: React gives a disabled button's presses only to its parents */}
      <span {...OWN_PRESS} className={classes.arrows}>
        <Button aria-label="Move divider earlier" icon={<UpOutlined />} disabled={index <= 1}
          onClick={() => dispatch({ type: 'stepDivider', key, step: -1 })} />
        <Button aria-label="Move divider later" icon={<DownOutlined />} disabled={index >= count - 1}
          onClick={() => dispatch({ type: 'stepDivider', key, step: 1 })} />
      </span>
      <Button {...OWN_PRESS} danger onClick={() => dispatch({ type: 'removeDivider', key })}>Remove Divider</Button>
    </div>
  )
}

DividerRow.propTypes = {
  section: PropTypes.shape({ key: PropTypes.string.isRequired, title: PropTypes.string }).isRequired,
  index: PropTypes.number.isRequired,
  count: PropTypes.number.isRequired,
  dispatch: PropTypes.func.isRequired,
  handle: PropTypes.node,
  dragListeners: PropTypes.object
}
