import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { Button, Modal } from 'antd'
import { LeftOutlined } from '@ant-design/icons'

import WidgetFrame from '../WidgetFrame/WidgetFrame'
import { CameraPlaceholder } from '../widgets/Printer/CameraStream'
import { FIXTURE_NOW, PRINTERS } from '../widgets/Printer/fixtures'
import { FLEET, HISTORY, QUEUE } from '../widgets/PrintQueue/fixtures'
import { REGISTRY, SIZES } from '../widgets/registry'
import { Printer3DOutlined } from '../../../components/icons'
import * as classes from './AddWidgetModal.module.less'

// Previews are the real widgets at their grid size (168 px rows and columns, 12 px gaps), shown at 60%
const CELL = 168
const GAP = 12
const SCALE = 0.6
const span = (units) => units * CELL + (units - 1) * GAP

// Fixture data, never the user's printers: a printer printing, and a fleet with a queue
const PREVIEW_PRINTER = { ...PRINTERS.PRINTING, name: 'Printer name' }
const PREVIEWS = {
  PRINTER: (entry, size) => (
    <entry.Preview printer={PREVIEW_PRINTER} size={size} options={entry.defaultOptions(size)} now={FIXTURE_NOW}
      cameraStream={<CameraPlaceholder />} />
  ),
  PRINT_QUEUE: (entry, size) => (
    <entry.Preview printers={FLEET} size={size} options={entry.defaultOptions(size)} queue={QUEUE} history={HISTORY}
      now={FIXTURE_NOW} />
  )
}

// A widget type at one size, as a button that adds it
function SizeChoice ({ type, size, label, onPick }) {
  const entry = REGISTRY[type]
  const { widthUnits, heightUnits } = SIZES[size]
  const width = span(widthUnits)
  const height = span(heightUnits)
  return (
    <button type="button" className={classes.choice} aria-label={label} onClick={onPick}
      style={{ width: Math.round(width * SCALE), height: Math.round(height * SCALE) }}>
      <span className={classes.scaled} style={{ width, height }} inert>
        <WidgetFrame label={entry.name}>{PREVIEWS[type](entry, size)}</WidgetFrame>
      </span>
    </button>
  )
}

// Add Widget (mockup board 2): the Divider and every widget type at each of its sizes. A widget about one printer
// asks which one next. New widgets go at the end of the last section. Nothing in the gallery streams.
export default function AddWidgetModal ({ open, printers, dispatch, onClose }) {
  const [pending, setPending] = useState(null)
  const close = () => {
    setPending(null)
    onClose()
  }
  const add = (action) => {
    dispatch(action)
    close()
  }
  const pendingLabel = pending && `${REGISTRY[pending.type].name} (${SIZES[pending.size].label})`

  const title = (
    <div className={classes.header}>
      <span>Add Widget</span>
      <Button type="text" onClick={close}>Close</Button>
    </div>
  )
  return (
    <Modal open={open} title={title} closable={false} footer={null} width={760} onCancel={close} destroyOnHidden>
      {pending
        ? (
          <>
            <p className={classes.question}>Which printer should the {pendingLabel} widget show?</p>
            {printers.map((printer) => (
              <button key={printer.id} type="button" className={classes.printer}
                aria-label={`Add ${pendingLabel} widget for ${printer.name}`}
                onClick={() => add({ type: 'addWidget', widgetType: pending.type, size: pending.size, printerId: printer.id })}>
                <Printer3DOutlined /><span>{printer.name}</span>
              </button>
            ))}
            <Button className={classes.back} icon={<LeftOutlined />} onClick={() => setPending(null)}>Back to Widgets</Button>
          </>
          )
        : (
          <>
            <div className={classes.entry}>
              <span className={classes.name}>Divider</span>
              <button type="button" className={classes.divider} aria-label="Add Divider, Full width"
                onClick={() => add({ type: 'addDivider' })}>
                <span>Workshop</span><span className={classes.line} />
              </button>
            </div>
            {Object.entries(REGISTRY).map(([type, entry]) => {
              // A Printer widget needs its printer; a Print Queue starts with all printers
              const needsPrinter = !entry.settings.allPrinters
              return (
                <div key={type} className={classes.entry}>
                  <span className={classes.name}>{entry.name}</span>
                  <div className={classes.sizes}>
                    {entry.sizes.map((size) => (
                      <SizeChoice key={size} type={type} size={size}
                        label={`${needsPrinter ? 'Choose' : 'Add'} ${entry.name}, ${SIZES[size].label}`}
                        onPick={() => (needsPrinter
                          ? setPending({ type, size })
                          : add({ type: 'addWidget', widgetType: type, size, printerId: null }))} />
                    ))}
                  </div>
                </div>
              )
            })}
          </>
          )}
    </Modal>
  )
}

AddWidgetModal.propTypes = {
  open: PropTypes.bool.isRequired,
  printers: PropTypes.arrayOf(PropTypes.shape({ id: PropTypes.string.isRequired, name: PropTypes.string.isRequired }))
    .isRequired,
  dispatch: PropTypes.func.isRequired,
  onClose: PropTypes.func.isRequired
}

SizeChoice.propTypes = {
  type: PropTypes.string.isRequired,
  size: PropTypes.string.isRequired,
  label: PropTypes.string.isRequired,
  onPick: PropTypes.func.isRequired
}
