import React from 'react'
import PropTypes from 'prop-types'
import { Checkbox, Select } from 'antd'

import * as classes from './WidgetSettings.module.less'

const ALL_PRINTERS = 'all'

// The options a widget of `entry`'s type shows at `size` (one printer's queue has no row per printer), and the labels
// of those only larger sizes show
export function optionsAt (entry, size, onePrinter) {
  const fits = (option) => !(option.allPrintersOnly && onePrinter)
  const shown = entry.optionsFor(size).filter(fits)
  const at = entry.sizes.indexOf(size)
  const larger = entry.sizes.slice(at + 1).flatMap((bigger) => entry.optionsFor(bigger).filter(fits))
  const later = [...new Set(larger.map((option) => option.label))]
    .filter((label) => !shown.some((option) => option.label === label))
  return { shown, later }
}

const hintAt = (option, size) => (typeof option.hint === 'object' ? option.hint[size] : option.hint)

// The gear menu of a widget in edit mode (mockup board 4): which printer or queue it follows, and the options its
// size shows, saying what larger sizes add. `entry` is the widget's registry entry, whose `settings` name the menu.
// Changes go to the draft through `dispatch`.
export default function WidgetSettings ({ entry, widget, size, sizeLabel, printers, dispatch }) {
  const { title, pickerLabel, allPrinters } = entry.settings
  const printerId = widget.printer?.id ?? null
  const { shown, later } = optionsAt(entry, size, !!printerId)
  const choices = [
    ...(allPrinters ? [{ value: ALL_PRINTERS, label: 'All printers' }] : []),
    ...printers.map((printer) => ({ value: printer.id, label: printer.name }))
  ]
  const pick = (value) => dispatch({ type: 'setPrinter', key: widget.key, printerId: value === ALL_PRINTERS ? null : value })

  return (
    <div role="group" aria-label={title} className={classes.settings}>
      <div className={classes.heading}>
        <span className={classes.title}>{title}</span>
        <span className={classes.secondary}>{sizeLabel}</span>
      </div>
      <div className={classes.field}>
        <span className={classes.label}>{pickerLabel}</span>
        <Select showSearch={{ optionFilterProp: 'label' }} options={choices} aria-label={pickerLabel}
          value={printerId ?? (allPrinters ? ALL_PRINTERS : undefined)} placeholder="Choose a printer"
          onChange={pick} className={classes.select} />
      </div>
      {shown.length > 0 && (
        <div className={classes.show}>
          <span className={classes.label}>Show</span>
          {shown.map((option) => (
            <div key={option.key} className={classes.toggle}>
              <Checkbox checked={!!widget.options[option.key]} onChange={(event) => dispatch({
                type: 'setOption', key: widget.key, option: option.key, value: event.target.checked
              })}>
                {option.label}
              </Checkbox>
              {hintAt(option, size) && <span className={classes.hint}>{hintAt(option, size)}</span>}
            </div>
          ))}
        </div>
      )}
      {later.length > 0 && <span className={classes.secondary}>Larger sizes add: {later.join(', ')}</span>}
    </div>
  )
}

WidgetSettings.propTypes = {
  entry: PropTypes.shape({
    sizes: PropTypes.arrayOf(PropTypes.string).isRequired,
    optionsFor: PropTypes.func.isRequired,
    settings: PropTypes.shape({
      title: PropTypes.string.isRequired, pickerLabel: PropTypes.string.isRequired, allPrinters: PropTypes.bool
    }).isRequired
  }).isRequired,
  widget: PropTypes.shape({
    key: PropTypes.string.isRequired, printer: PropTypes.shape({ id: PropTypes.string }), options: PropTypes.object.isRequired
  }).isRequired,
  size: PropTypes.string.isRequired,
  sizeLabel: PropTypes.string.isRequired,
  printers: PropTypes.arrayOf(PropTypes.shape({ id: PropTypes.string.isRequired, name: PropTypes.string.isRequired }))
    .isRequired,
  dispatch: PropTypes.func.isRequired
}
