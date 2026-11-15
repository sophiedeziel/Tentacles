import React from 'react'
import PropTypes from 'prop-types'

import WidgetFrame from '../WidgetFrame/WidgetFrame'
import { canStep } from '../layout/layoutReducer'
import { REGISTRY, sizeOf } from '../widgets/registry'
import DividerRow from './DividerRow'
import * as classes from './Section.module.less'

// A widget's edit tools, wired to the draft
function editTools (widget, size, data, { sections, dispatch }) {
  const { key } = widget
  const entry = REGISTRY[widget.type]
  return {
    title: entry.title(data.printersById?.[widget.printer?.id]),
    sizes: entry.sizes,
    size,
    onResize: (to) => dispatch({ type: 'resizeWidget', key, size: to }),
    canMoveEarlier: canStep(sections, key, -1),
    canMoveLater: canStep(sections, key, 1),
    onMove: (step) => dispatch({ type: 'stepWidget', key, step }),
    onRemove: () => dispatch({ type: 'removeWidget', key })
  }
}

// A run of widgets under an optional divider title, laid out on the section's own grid.
// In edit mode (`editor`: the draft's { sections, dispatch }) the divider and the widgets get their edit tools.
export default function Section ({ section, data, index = 0, editor = null }) {
  const untitled = index === 0 ? 'Top of dashboard' : 'Untitled section'
  return (
    <section className={classes.section} aria-label={section.title || untitled}>
      {editor && index > 0 && (
        <DividerRow section={section} index={index} count={editor.sections.length} dispatch={editor.dispatch} />
      )}
      {!editor && section.title && <div className={classes.divider}>{section.title}</div>}
      <div className={classes.grid}>
        {section.widgets.map((widget) => {
          const entry = REGISTRY[widget.type]
          const size = sizeOf(widget)
          if (!entry?.Component || !size) return null

          const { Component } = entry
          return (
            <div key={widget.key || widget.id} className={classes.cell} data-size={size} style={{
              '--width-units': widget.widthUnits,
              '--width-units-md': Math.min(widget.widthUnits, 2),
              '--height-units': widget.heightUnits
            }}>
              <WidgetFrame label={entry.name} edit={editor && editTools(widget, size, data, editor)}>
                <Component widget={widget} size={size} data={data} />
              </WidgetFrame>
            </div>
          )
        })}
        {editor && index > 0 && section.widgets.length === 0 && (
          <div className={classes.dropTile}>Drag widgets here</div>
        )}
      </div>
    </section>
  )
}

Section.propTypes = {
  section: PropTypes.shape({
    id: PropTypes.string,
    key: PropTypes.string,
    title: PropTypes.string,
    widgets: PropTypes.arrayOf(PropTypes.shape({
      id: PropTypes.string,
      key: PropTypes.string,
      type: PropTypes.string.isRequired,
      widthUnits: PropTypes.number.isRequired,
      heightUnits: PropTypes.number.isRequired
    })).isRequired
  }).isRequired,
  data: PropTypes.object.isRequired,
  index: PropTypes.number,
  editor: PropTypes.shape({ sections: PropTypes.array.isRequired, dispatch: PropTypes.func.isRequired })
}
