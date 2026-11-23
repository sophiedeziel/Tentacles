import React, { createContext, useContext, useMemo } from 'react'
import PropTypes from 'prop-types'
import { Button } from 'antd'
import { HolderOutlined } from '@ant-design/icons'
import { DndContext, KeyboardSensor, MouseSensor, TouchSensor, closestCenter, useSensor, useSensors } from '@dnd-kit/core'
import {
  SortableContext, arrayMove, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'

// Drag to reorder the rows of an antd Table, by a handle on each row (DragHandle), with a mouse, a finger or the
// keyboard (Space or Enter picks the row up, the arrows move it, Space or Enter drops it, Esc puts it back).
// `SortableRow` is the Table's body row (`components.body.row`): rows are sortable by their key.

// A mouse has to move 4 px before a drag starts, so a click on the handle does nothing. A finger rests 200 ms first:
// moving sooner scrolls the page.
const MOUSE = { activationConstraint: { distance: 4 } }
const TOUCH = { activationConstraint: { delay: 200, tolerance: 5 } }
const KEYBOARD = { coordinateGetter: sortableKeyboardCoordinates }

// Rows move up and down only
const verticalOnly = ({ transform }) => ({ ...transform, x: 0 })

// Where a row dropped on another one lands: { id, ids, target }, the row moved, the new order of the ids, and what
// movePrintJob is told. `beforeId` is the row it now sits right above; the last row goes to the bottom. Null when it
// didn't move.
export function dropMove (ids, activeId, overId) {
  if (overId == null || activeId === overId) return null
  const from = ids.indexOf(activeId)
  const to = ids.indexOf(overId)
  if (from < 0 || to < 0) return null

  const next = arrayMove(ids, from, to)
  const index = next.indexOf(activeId)
  const target = index === next.length - 1 ? { to: 'BOTTOM' } : { beforeId: next[index + 1] }
  return { id: activeId, ids: next, target }
}

// What a screen reader hears while a row moves, by name (`nameOf(id)`) and position
function announcementsFor (ids, nameOf) {
  const position = (id) => `position ${ids.indexOf(id) + 1} of ${ids.length}`
  return {
    onDragStart: ({ active }) => `Picked up ${nameOf(active.id)}, at ${position(active.id)}.`,
    onDragOver: ({ active, over }) => over && `${nameOf(active.id)} is over ${position(over.id)}.`,
    onDragEnd: ({ active, over }) => (over
      ? `${nameOf(active.id)} was dropped at ${position(over.id)}.`
      : `${nameOf(active.id)} was dropped where it was.`),
    onDragCancel: ({ active }) => `Moving ${nameOf(active.id)} was cancelled: it is back where it was.`
  }
}

// The drag and drop context of a table's rows. `ids` are the row keys in the order shown; `onDragStart()`, then
// `onDrop(move)` with dropMove's answer (null when the row didn't move, or the drag was cancelled).
export default function SortableRows ({ ids, nameOf, onDragStart, onDrop, children }) {
  const sensors = useSensors(
    useSensor(MouseSensor, MOUSE), useSensor(TouchSensor, TOUCH), useSensor(KeyboardSensor, KEYBOARD)
  )
  const accessibility = useMemo(() => ({ announcements: announcementsFor(ids, nameOf) }), [ids, nameOf])

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} modifiers={[verticalOnly]}
      accessibility={accessibility}
      onDragStart={onDragStart}
      onDragEnd={({ active, over }) => onDrop(dropMove(ids, active.id, over?.id))}
      onDragCancel={() => onDrop(null)}>
      <SortableContext items={ids} strategy={verticalListSortingStrategy}>
        {children}
      </SortableContext>
    </DndContext>
  )
}

// The handle's ref, listeners and attributes, from the row it is on
const RowContext = createContext(null)

// A sortable body row. Rows without a key (a batch's expanded copies) are plain rows: they move with their batch.
export function SortableRow (props) {
  if (props['data-row-key'] == null) return <tr {...props} />
  return <SortableKeyedRow {...props} />
}

function SortableKeyedRow (props) {
  const { attributes, listeners, setNodeRef, setActivatorNodeRef, transform, transition, isDragging } = useSortable({
    id: props['data-row-key']
  })
  const handle = useMemo(
    () => ({ attributes, listeners, setActivatorNodeRef, isDragging }),
    [attributes, listeners, setActivatorNodeRef, isDragging]
  )
  const style = {
    ...props.style,
    transform: CSS.Translate.toString(transform),
    transition,
    ...(isDragging ? { position: 'relative', zIndex: 2 } : {})
  }

  return (
    <RowContext.Provider value={handle}>
      <tr {...props} ref={setNodeRef} style={style} />
    </RowContext.Provider>
  )
}

// The row's grip: what picks the row up, by pointer or keyboard. `label` names the row ("Drag phone_stand.gcode").
export function DragHandle ({ label }) {
  const { attributes, listeners, setActivatorNodeRef, isDragging } = useContext(RowContext)

  return (
    <Button ref={setActivatorNodeRef} type="text" size="small" icon={<HolderOutlined />} {...attributes} {...listeners}
      aria-label={label} style={{ cursor: isDragging ? 'grabbing' : 'grab', touchAction: 'none' }} />
  )
}

SortableRows.propTypes = {
  ids: PropTypes.arrayOf(PropTypes.string).isRequired,
  nameOf: PropTypes.func.isRequired,
  onDragStart: PropTypes.func.isRequired,
  onDrop: PropTypes.func.isRequired,
  children: PropTypes.node.isRequired
}
SortableRow.propTypes = { 'data-row-key': PropTypes.oneOfType([PropTypes.string, PropTypes.number]), style: PropTypes.object }
SortableKeyedRow.propTypes = SortableRow.propTypes
DragHandle.propTypes = { label: PropTypes.string.isRequired }
