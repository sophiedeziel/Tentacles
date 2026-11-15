import React from 'react'
import PropTypes from 'prop-types'
import { HolderOutlined } from '@ant-design/icons'
import { SortableContext } from '@dnd-kit/sortable'

import WidgetFrame from '../WidgetFrame/WidgetFrame'
import { canStep } from '../layout/layoutReducer'
import { useDragType, useSectionEnd, useSortableItem } from '../LayoutDnd/LayoutDnd'
import { REGISTRY, sizeOf } from '../widgets/registry'
import DividerRow from './DividerRow'
import * as classes from './Section.module.less'

// A widget's edit tools, wired to the draft
function editTools (widget, size, title, { sections, dispatch }) {
  const { key } = widget
  return {
    title,
    sizes: REGISTRY[widget.type].sizes,
    size,
    onResize: (to) => dispatch({ type: 'resizeWidget', key, size: to }),
    canMoveEarlier: canStep(sections, key, -1),
    canMoveLater: canStep(sections, key, 1),
    onMove: (step) => dispatch({ type: 'stepWidget', key, step }),
    onRemove: () => dispatch({ type: 'removeWidget', key })
  }
}

// Dragging moves widgets in the draft as it goes (see dragOverAction): nothing is shifted to preview a move
const NO_PREVIEW = () => null

const spanStyle = (widget) => ({
  '--width-units': widget.widthUnits,
  '--width-units-md': Math.min(widget.widthUnits, 2),
  '--height-units': widget.heightUnits
})

// In edit mode a widget is picked up anywhere on it, or with Space when the widget itself has focus: the cell is its
// own activator, so Enter and Space on its tools click them
function SortableCell ({ widget, size, title, children }) {
  const sortable = useSortableItem(widget.key, 'widget')
  const { setNodeRef, setActivatorNodeRef } = sortable
  const ref = (node) => {
    setNodeRef(node)
    setActivatorNodeRef(node)
  }
  return (
    <div ref={ref} className={sortable.isDragging ? classes.cellDragging : classes.cell}
      data-size={size} style={{ ...spanStyle(widget), ...sortable.style }} {...sortable.attributes}
      {...sortable.listeners} aria-label={title}>
      {children}
    </div>
  )
}

// Where a dragged widget joins the end of a section. An empty divider always shows it.
function SectionEnd ({ section, index }) {
  const { setNodeRef, isOver } = useSectionEnd(section.key)
  const draggingWidget = useDragType() === 'widget'
  const empty = section.widgets.length === 0
  if (!draggingWidget && !(empty && index > 0)) return null

  return (
    <div ref={setNodeRef} className={isOver ? classes.dropTileOver : classes.dropTile}>
      {empty ? 'Drag widgets here' : 'Drop at the end of this row'}
    </div>
  )
}

// A run of widgets under an optional divider title, laid out on the section's own grid.
// In edit mode (`editor`: the draft's { sections, dispatch }) the divider and the widgets get their edit tools, and
// the widgets sort by drag and drop. `sortable` (SortableSection) lets the divider drag its section.
export default function Section ({ section, data, index = 0, editor = null, sortable = null }) {
  const untitled = index === 0 ? 'Top of dashboard' : 'Untitled section'
  const cells = section.widgets.map((widget) => {
    const entry = REGISTRY[widget.type]
    const size = sizeOf(widget)
    if (!entry?.Component || !size) return null

    const { Component } = entry
    const content = <Component widget={widget} size={size} data={data} />
    if (!editor) {
      return (
        <div key={widget.id} className={classes.cell} data-size={size} style={spanStyle(widget)}>
          <WidgetFrame label={entry.name}>{content}</WidgetFrame>
        </div>
      )
    }
    const title = entry.title(data.printersById?.[widget.printer?.id])
    return (
      <SortableCell key={widget.key} widget={widget} size={size} title={title}>
        <WidgetFrame label={entry.name} edit={editTools(widget, size, title, editor)}>{content}</WidgetFrame>
      </SortableCell>
    )
  })

  return (
    <section ref={sortable?.setNodeRef} style={sortable?.style} aria-label={section.title || untitled}
      className={sortable?.isDragging ? classes.sectionDragging : classes.section}>
      {editor && index > 0 && (
        <DividerRow section={section} index={index} count={editor.sections.length} dispatch={editor.dispatch}
          handle={sortable && (
            <button type="button" ref={sortable.setActivatorNodeRef} className={classes.handle}
              {...sortable.attributes} {...sortable.listeners} aria-label={`Drag ${section.title || untitled}`}>
              <HolderOutlined />
            </button>
          )} />
      )}
      {!editor && section.title && <div className={classes.divider}>{section.title}</div>}
      <div className={classes.grid}>
        {editor
          ? (
            <SortableContext id={section.key} items={section.widgets.map((widget) => widget.key)}
              strategy={NO_PREVIEW}>
              {cells}
            </SortableContext>
            )
          : cells}
        {editor && <SectionEnd section={section} index={index} />}
      </div>
    </section>
  )
}

const widgetShape = PropTypes.shape({
  id: PropTypes.string,
  key: PropTypes.string,
  type: PropTypes.string.isRequired,
  widthUnits: PropTypes.number.isRequired,
  heightUnits: PropTypes.number.isRequired
})
const sectionShape = PropTypes.shape({
  id: PropTypes.string,
  key: PropTypes.string,
  title: PropTypes.string,
  widgets: PropTypes.arrayOf(widgetShape).isRequired
})

Section.propTypes = {
  section: sectionShape.isRequired,
  data: PropTypes.object.isRequired,
  index: PropTypes.number,
  editor: PropTypes.shape({ sections: PropTypes.array.isRequired, dispatch: PropTypes.func.isRequired }),
  sortable: PropTypes.object
}

// A divider's section in edit mode, sortable among the sections by its handle (the first section has no divider)
export function SortableSection (props) {
  const sortable = useSortableItem(props.section.key, 'section')
  return <Section {...props} sortable={sortable} />
}

SortableSection.propTypes = Section.propTypes

// What follows the pointer while a widget is dragged: the widget as it is, unusable
export function WidgetOverlay ({ widget, data }) {
  const entry = REGISTRY[widget.type]
  const size = sizeOf(widget)
  if (!entry?.Component || !size) return null
  const { Component } = entry
  return (
    <div className={classes.overlay} inert>
      <WidgetFrame label={entry.name}><Component widget={widget} size={size} data={data} /></WidgetFrame>
    </div>
  )
}

WidgetOverlay.propTypes = { widget: widgetShape.isRequired, data: PropTypes.object.isRequired }

// What follows the pointer while a divider is dragged
export function SectionOverlay ({ section }) {
  return (
    <div className={classes.dividerOverlay}>
      <HolderOutlined />{section.title || 'Untitled section'}
    </div>
  )
}

SectionOverlay.propTypes = { section: sectionShape.isRequired }
SortableCell.propTypes = {
  widget: widgetShape.isRequired, size: PropTypes.string.isRequired, title: PropTypes.string.isRequired, children: PropTypes.node
}
SectionEnd.propTypes = { section: sectionShape.isRequired, index: PropTypes.number.isRequired }
