import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { Card, Popover } from 'antd'
import { LeftOutlined, MinusOutlined, RightOutlined, SettingOutlined } from '@ant-design/icons'

import { SIZES } from '../widgets/registry'
import * as classes from './WidgetFrame.module.less'

const STYLES = {
  root: { height: '100%' },
  body: { height: '100%', padding: 12, display: 'flex', flexDirection: 'column', boxSizing: 'border-box' }
}

// The menu renders outside the widget, but React still bubbles its events to the widget: they mustn't start a drag
const stop = (event) => event.stopPropagation()

// The gear, opening the widget's settings form in a popover
function Gear ({ title, settings }) {
  const [open, setOpen] = useState(false)
  return (
    <Popover trigger="click" placement="bottom" arrow={false} open={open} onOpenChange={setOpen}
      content={<div onMouseDown={stop} onTouchStart={stop} onKeyDown={stop}>{settings}</div>}>
      <button type="button" className={classes.tool} aria-label={`Settings for ${title}`} aria-expanded={open}>
        <SettingOutlined />
      </button>
    </Popover>
  )
}

// Edit mode's tools around a widget: remove (−) at the top left, and a toolbar with the sizes its type supports,
// ‹ › to move it without dragging and its gear
function EditTools ({ edit }) {
  return (
    <>
      <button type="button" className={classes.remove} aria-label={`Remove ${edit.title}`} onClick={edit.onRemove}>
        <MinusOutlined />
      </button>
      <div className={classes.tools}>
        <div className={classes.group} role="group" aria-label="Widget size">
          {edit.sizes.map((size) => (
            <button key={size} type="button" aria-label={SIZES[size].label} aria-pressed={size === edit.size}
              className={size === edit.size ? classes.sizeOn : classes.tool} onClick={() => edit.onResize(size)}>
              {size}
            </button>
          ))}
        </div>
        <div className={classes.group}>
          <button type="button" className={classes.tool} aria-label="Move earlier" disabled={!edit.canMoveEarlier}
            onClick={() => edit.onMove(-1)}><LeftOutlined /></button>
          <button type="button" className={classes.tool} aria-label="Move later" disabled={!edit.canMoveLater}
            onClick={() => edit.onMove(1)}><RightOutlined /></button>
          {edit.settings && <Gear title={edit.title} settings={edit.settings} />}
        </div>
      </div>
    </>
  )
}

// The card every widget sits in. In edit mode (`edit` set) the widget can't be used, only arranged: its content is
// inert, and the frame adds the edit tools.
export default function WidgetFrame ({ children, label, edit = null }) {
  if (!edit) return <Card size="small" styles={STYLES} aria-label={label}>{children}</Card>

  return (
    <div className={classes.editing}>
      <div className={classes.content} inert>
        <Card size="small" styles={STYLES} aria-label={label}>{children}</Card>
      </div>
      <EditTools edit={edit} />
    </div>
  )
}

const editShape = PropTypes.shape({
  title: PropTypes.string.isRequired,
  sizes: PropTypes.arrayOf(PropTypes.string).isRequired,
  size: PropTypes.string.isRequired,
  onResize: PropTypes.func.isRequired,
  canMoveEarlier: PropTypes.bool,
  canMoveLater: PropTypes.bool,
  onMove: PropTypes.func.isRequired,
  onRemove: PropTypes.func.isRequired,
  settings: PropTypes.node
})

WidgetFrame.propTypes = {
  children: PropTypes.node,
  label: PropTypes.string,
  edit: editShape
}

EditTools.propTypes = { edit: editShape.isRequired }
Gear.propTypes = { title: PropTypes.string.isRequired, settings: PropTypes.node.isRequired }
