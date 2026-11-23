import React from 'react'
import PropTypes from 'prop-types'
import fileSize from 'file-size'
import { Button, Card, Checkbox, InputNumber, Segmented, Select, Skeleton, Switch, Tooltip, Typography, theme } from 'antd'
import { CheckOutlined, ClockCircleOutlined, ReloadOutlined, StopOutlined } from '@ant-design/icons'

import PrinterStatus from '../../../components/PrinterStatus/PrinterStatus'
import { GcodeFileOutlined } from '../../../components/icons'
import { ANY_COLOUR, colourHint, fitView, materialHint } from './formRules'
import * as classes from './AddToQueue.module.less'

const { Text } = Typography

// The most copies one job asks for
export const MAX_COPIES = 999

const Muted = ({ children, small = false }) => (
  <Text type="secondary" className={small ? classes.small : undefined}>{children}</Text>
)

// A card of the form, titled like the frames, with `extra` on the right. A landmark named after its title.
export function FormCard ({ title, count, extra, className, children }) {
  const heading = (
    <span className={classes.cardTitle}>
      <h2>{title}</h2>
      {count != null && <Text type="secondary" className={classes.count}>{count}</Text>}
    </span>
  )
  return (
    <section aria-label={title}>
      <Card title={heading} extra={extra} className={`${classes.card} ${className ?? ''}`}>{children}</Card>
    </section>
  )
}

// A setting's name and what it does, its control on the right
function Option ({ title, description, children }) {
  return (
    <div className={`${classes.option} ${classes.divided}`}>
      <div className={classes.optionText}>
        <Text strong>{title}</Text>
        <Muted>{description}</Muted>
      </div>
      {children}
    </div>
  )
}

// "PrusaSlicer · 2.4 MB": the slicer when the G-code says it
const fileFacts = (file) => [file.gcodeSummary?.slicer, fileSize(file.filesize).human('si')].filter(Boolean).join(' · ')

// File and Copies: the file, how many copies, and its notes
export function FileCard ({ file, copies, onCopies }) {
  const { token } = theme.useToken()
  return (
    <FormCard title="File and Copies">
      <div className={classes.fileRow}>
        <div className={classes.fileLine}>
          <GcodeFileOutlined aria-hidden style={{ color: token.colorTextSecondary }} />
          <span className={classes.fileName} title={file.filename}>{file.filename}</span>
          <Muted small>{fileFacts(file)}</Muted>
        </div>
        <label className={classes.field}>
          <Muted small>Copies</Muted>
          <InputNumber mode="spinner" min={1} max={MAX_COPIES} precision={0} value={copies} aria-label="Copies"
            onChange={(value) => onCopies(value ?? 1)} style={{ width: 128 }} />
        </label>
      </div>
      <p className={classes.paragraph}>
        <Muted>Copies stay together as one batch in the queue. Each copy is its own print job.</Muted>
      </p>
      {file.notes?.trim() && (
        <div className={classes.notes} style={{ background: token.colorFillQuaternary }}>
          <Muted small>Notes on this file</Muted>
          <div>{file.notes}</div>
        </div>
      )}
    </FormCard>
  )
}

// A field with its reset button (back to what the G-code says) and the line under it
function FilamentField ({ label, control, onReset, resetDisabled, hint }) {
  return (
    <div className={classes.field}>
      <Muted small>{label}</Muted>
      <div className={classes.fieldRow}>
        {control}
        <Tooltip title="Back to what the G-code says">
          <Button icon={<ReloadOutlined />} onClick={onReset} disabled={resetDisabled}
            aria-label={`Reset ${label.toLowerCase()} to the G-code's`} />
        </Tooltip>
      </div>
      <Muted small>{hint}</Muted>
    </div>
  )
}

const mm = (value) => {
  const rounded = Math.round(value * 10) / 10
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1)
}

// "120 × 80 × 28 mm", the height left out when it isn't known
const footprintText = (footprint) => [footprint.width, footprint.depth, footprint.height]
  .filter((value) => value != null).map(mm).join(' × ') + ' mm'

// Filament: the material and the colour the job asks for, prefilled from the G-code (see formRules), and its
// footprint. A job's temperatures are not shown: nothing checks them.
export function FilamentCard ({ fields, gcode, materials, colours, footprint, onChange }) {
  const { token } = theme.useToken()
  const colourOptions = [
    { value: ANY_COLOUR, label: 'Any Colour' },
    ...[...new Set([...colours, fields.colour, gcode.colour].filter((colour) => colour && colour !== ANY_COLOUR))]
      .map((colour) => ({ value: colour, label: colour }))
  ]
  const materialOptions = [...new Set([...materials, fields.material].filter(Boolean))]
    .map((material) => ({ value: material, label: material }))
  const severalTools = gcode.tools > 1

  return (
    <FormCard title="Filament">
      <div className={classes.filamentFields}>
        <FilamentField label="Material"
          control={(
            <Select className={classes.select} aria-label="Material" placeholder="Not known" showSearch
              value={fields.material ?? undefined} options={materialOptions} disabled={severalTools}
              onChange={(material) => onChange({ ...fields, material })} />
          )}
          onReset={() => onChange({ ...fields, material: gcode.material })}
          resetDisabled={severalTools || !gcode.material || fields.material === gcode.material}
          hint={materialHint(fields.material, gcode)} />
        <FilamentField label="Colour"
          control={(
            <Select className={classes.select} aria-label="Colour" placeholder="Any Colour" showSearch
              value={fields.colour ?? undefined} options={colourOptions}
              onChange={(colour) => onChange({ ...fields, colour })} />
          )}
          onReset={() => onChange({ ...fields, colour: gcode.colour })}
          resetDisabled={!gcode.colour || fields.colour === gcode.colour}
          hint={(
            <span className={classes.hint}>
              {colourHint(fields.colour, gcode)}
              {gcode.hex && (
                <span className={classes.swatch} role="img" aria-label={`The G-code's colour, ${gcode.hex}`}
                  title={gcode.hex} style={{ background: gcode.hex, borderColor: token.colorBorder }} />
              )}
            </span>
          )} />
      </div>
      {footprint && (
        <div className={classes.facts}>
          <span><Muted>Footprint</Muted> {footprintText(footprint)}</span>
        </div>
      )}
    </FormCard>
  )
}

const MARKS = {
  ready: { Icon: CheckOutlined, colour: 'colorSuccess', label: 'Can print it' },
  waiting: { Icon: ClockCircleOutlined, colour: 'colorTextSecondary', label: 'Can print it later' },
  cannot: { Icon: StopOutlined, colour: 'colorTextSecondary', label: "Can't print it" }
}

const statusOf = (printer) => printer.status || { stateFamily: 'OFFLINE', stateText: 'Offline' }

function PrinterRow ({ fit, checked, onTick }) {
  const { token } = theme.useToken()
  const { mark, text } = fitView(fit)
  const { Icon, colour, label } = MARKS[mark]
  const status = statusOf(fit.printer)
  const disabled = fit.hardLimit
  return (
    <li className={classes.printerRow} data-printer-id={fit.printer.id}
      style={disabled ? { background: token.colorFillQuaternary } : undefined}>
      <Checkbox checked={checked} disabled={disabled} aria-label={fit.printer.name}
        onChange={(event) => onTick(fit.printer.id, event.target.checked)} />
      <Text className={classes.printerName} type={disabled ? 'secondary' : undefined}>{fit.printer.name}</Text>
      <span><PrinterStatus family={status.stateFamily} text={status.stateText} /></span>
      <span className={classes.fit}>
        <Icon aria-label={label} style={{ color: token[colour] }} />
        <span>{text}</span>
      </span>
    </li>
  )
}

// Printers: a row per printer with how it fits (printerFits), ticked when selected. A printer it can never print on
// is disabled. Select All and Clear; the same-printer switch under the rows.
export function PrintersCard ({ fits, loading, selected, onTick, onSelectAll, onClear, samePrinter, onSamePrinter }) {
  const selectable = (fits ?? []).filter((fit) => !fit.hardLimit)
  const allSelected = selectable.length > 0 && selectable.every((fit) => selected.includes(fit.printer.id))
  return (
    <FormCard title="Printers" className={classes.printers}
      count={fits ? `${selected.length} of ${selectable.length} selected` : null}
      extra={(
        <span className={classes.fieldRow}>
          <Button size="small" onClick={onSelectAll} disabled={!fits || allSelected}>Select All</Button>
          <Button size="small" onClick={onClear} disabled={selected.length === 0}>Clear</Button>
        </span>
      )}>
      <p className={classes.intro}>
        <Muted>
          The first printer you select that is ready prints it. A selected printer that is offline or has another
          filament loaded becomes ready once that changes.
        </Muted>
      </p>
      {!fits && loading && <div className={classes.switchRow}><Skeleton active title={false} paragraph={{ rows: 3 }} /></div>}
      {fits && (
        <ul className={classes.printerRows} aria-label="Printers that can print it">
          {fits.map((fit) => (
            <PrinterRow key={fit.printer.id} fit={fit} checked={selected.includes(fit.printer.id)} onTick={onTick} />
          ))}
        </ul>
      )}
      <div className={classes.switchRow}>
        <Option title="Keep all copies on the same printer"
          description={samePrinter
            ? 'On: the first selected printer that is ready takes every copy, one after another.'
            : 'Off: copies go to any selected printer that is ready, several at once.'}>
          <Switch checked={samePrinter} onChange={onSamePrinter} aria-label="Keep all copies on the same printer" />
        </Option>
      </div>
    </FormCard>
  )
}

// Order and Timing: where it goes in the queue, and whether it is held
export function OrderCard ({ position, onPosition, held, onHeld }) {
  return (
    <FormCard title="Order and Timing">
      <Option title="Position"
        description="Next Up goes ahead of everything waiting. Prints under way are not interrupted.">
        <Segmented value={position} onChange={onPosition} aria-label="Position"
          options={[{ value: 'BOTTOM', label: 'End of Queue' }, { value: 'TOP', label: 'Next Up' }]} />
      </Option>
      <Option title="Hold until I release it" description="It keeps its place in the queue, but no printer takes it.">
        <Switch checked={held} onChange={onHeld} aria-label="Hold until I release it" />
      </Option>
    </FormCard>
  )
}

const fieldsShape = PropTypes.shape({ material: PropTypes.string, colour: PropTypes.string })
const gcodeShape = PropTypes.shape({
  status: PropTypes.string,
  material: PropTypes.string,
  raw: PropTypes.string,
  colour: PropTypes.string,
  hex: PropTypes.string,
  tools: PropTypes.number
})
export const fitShape = PropTypes.shape({
  result: PropTypes.string.isRequired,
  hardLimit: PropTypes.bool.isRequired,
  reasons: PropTypes.arrayOf(PropTypes.shape({ code: PropTypes.string, message: PropTypes.string })).isRequired,
  printer: PropTypes.shape({ id: PropTypes.string.isRequired, name: PropTypes.string.isRequired }).isRequired
})

Muted.propTypes = { children: PropTypes.node, small: PropTypes.bool }
FormCard.propTypes = {
  title: PropTypes.string.isRequired,
  count: PropTypes.node,
  extra: PropTypes.node,
  className: PropTypes.string,
  children: PropTypes.node
}
Option.propTypes = { title: PropTypes.string.isRequired, description: PropTypes.node, children: PropTypes.node }
FileCard.propTypes = {
  file: PropTypes.shape({
    filename: PropTypes.string.isRequired,
    filesize: PropTypes.number.isRequired,
    notes: PropTypes.string,
    gcodeSummary: PropTypes.shape({ slicer: PropTypes.string })
  }).isRequired,
  copies: PropTypes.number.isRequired,
  onCopies: PropTypes.func.isRequired
}
FilamentField.propTypes = {
  label: PropTypes.string.isRequired,
  control: PropTypes.node.isRequired,
  onReset: PropTypes.func.isRequired,
  resetDisabled: PropTypes.bool,
  hint: PropTypes.node
}
FilamentCard.propTypes = {
  fields: fieldsShape.isRequired,
  gcode: gcodeShape.isRequired,
  materials: PropTypes.arrayOf(PropTypes.string).isRequired,
  colours: PropTypes.arrayOf(PropTypes.string).isRequired,
  footprint: PropTypes.shape({ width: PropTypes.number, depth: PropTypes.number, height: PropTypes.number }),
  onChange: PropTypes.func.isRequired
}
PrinterRow.propTypes = { fit: fitShape.isRequired, checked: PropTypes.bool.isRequired, onTick: PropTypes.func.isRequired }
PrintersCard.propTypes = {
  fits: PropTypes.arrayOf(fitShape),
  loading: PropTypes.bool,
  selected: PropTypes.arrayOf(PropTypes.string).isRequired,
  onTick: PropTypes.func.isRequired,
  onSelectAll: PropTypes.func.isRequired,
  onClear: PropTypes.func.isRequired,
  samePrinter: PropTypes.bool.isRequired,
  onSamePrinter: PropTypes.func.isRequired
}
OrderCard.propTypes = {
  position: PropTypes.oneOf(['TOP', 'BOTTOM']).isRequired,
  onPosition: PropTypes.func.isRequired,
  held: PropTypes.bool.isRequired,
  onHeld: PropTypes.func.isRequired
}
