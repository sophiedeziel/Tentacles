import React, { useRef, useState } from 'react'
import PropTypes from 'prop-types'
import {
  DndContext, DragOverlay, KeyboardSensor, MouseSensor, TouchSensor, useDndContext, useDroppable, useSensor, useSensors
} from '@dnd-kit/core'
import { SortableContext, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'

import layoutReducer from '../layout/layoutReducer'
import { collisions, dragEndAction, dragOverAction } from './dragMoves'

// A mouse has to move 8 px before a drag starts, so clicks on the widget tools still work. A finger has to rest
// 250 ms first: moving sooner scrolls the page, as it does outside edit mode. Once a drag starts it stops the scroll.
const MOUSE = { activationConstraint: { distance: 8 } }
const TOUCH = { activationConstraint: { delay: 250, tolerance: 5 } }
const KEYBOARD = { coordinateGetter: sortableKeyboardCoordinates }

// Live moves reflow the grid under the pointer, which can put the pointer over another widget and move it back: a
// move waits this long after the last one, and longer to go back over the same widget (as in the mockup)
const MOVE_INTERVAL = 140
const SAME_TARGET_INTERVAL = 450

// The DndContext handlers: a drag starts from a snapshot of the draft, moves widgets as it goes, and the drop makes
// the last move. Esc, or a drop outside any target, restores the snapshot.
export function useDragHandlers (sections, dispatch, clock = Date.now) {
  const snapshot = useRef(null)
  const lastMove = useRef({ at: 0, target: null })
  const [active, setActive] = useState(null)
  const apply = (action) => action && dispatch(action)
  const finish = () => {
    snapshot.current = null
    setActive(null)
  }
  const moveLive = (dragged, over) => {
    const action = dragOverAction(sections, dragged, over)
    if (!action || layoutReducer(sections, action) === sections) return
    const now = clock()
    const since = now - lastMove.current.at
    if (since < MOVE_INTERVAL || (over.id === lastMove.current.target && since < SAME_TARGET_INTERVAL)) return
    lastMove.current = { at: now, target: over.id }
    dispatch(action)
  }

  return {
    active,
    onDragStart: (event) => {
      snapshot.current = sections
      lastMove.current = { at: 0, target: null }
      setActive({ id: event.active.id, type: event.active.data.current?.type })
    },
    onDragOver: ({ active: dragged, over }) => moveLive(dragged, over),
    onDragEnd: ({ active: dragged, over }) => {
      if (over) apply(dragEndAction(sections, dragged, over))
      else if (snapshot.current) dispatch({ type: 'restore', sections: snapshot.current })
      finish()
    },
    onDragCancel: () => {
      if (snapshot.current) dispatch({ type: 'restore', sections: snapshot.current })
      finish()
    }
  }
}

// Drag and drop for edit mode: widgets within and between sections, and dividers (with their widgets) among the
// sections. `renderOverlay(active)` draws what follows the pointer ({ id, type }).
export default function LayoutDnd ({ sections, dispatch, renderOverlay, children }) {
  const sensors = useSensors(
    useSensor(MouseSensor, MOUSE), useSensor(TouchSensor, TOUCH), useSensor(KeyboardSensor, KEYBOARD)
  )
  const { active, ...handlers } = useDragHandlers(sections, dispatch)

  return (
    <DndContext sensors={sensors} collisionDetection={collisions} {...handlers}>
      {/* The dividers: the untitled first section stays first */}
      <SortableContext items={sections.slice(1).map((section) => section.key)} strategy={verticalListSortingStrategy}>
        {children}
      </SortableContext>
      <DragOverlay>{active && renderOverlay(active)}</DragOverlay>
    </DndContext>
  )
}

LayoutDnd.propTypes = {
  sections: PropTypes.array.isRequired,
  dispatch: PropTypes.func.isRequired,
  renderOverlay: PropTypes.func.isRequired,
  children: PropTypes.node
}

// The type of what is being dragged: 'widget', 'section' or undefined
export function useDragType () {
  return useDndContext().active?.data.current?.type
}

// A sortable item's ref, attributes, listeners and style. Only what can take the dragged item is a drop target, so
// the keyboard moves a widget among widgets and a divider among dividers.
export function useSortableItem (id, type, { draggable = true } = {}) {
  const dragType = useDragType()
  const sortable = useSortable({
    id,
    data: { type },
    disabled: { draggable: !draggable, droppable: !!dragType && dragType !== type }
  })
  // Translate only: a sorting strategy may also scale an item to the size of the one it takes the place of
  const style = { transform: CSS.Translate.toString(sortable.transform), transition: sortable.transition }
  return { ...sortable, style }
}

// The drop target at the end of a section
export function useSectionEnd (sectionKey) {
  return useDroppable({ id: `end:${sectionKey}`, data: { type: 'end', sectionKey } })
}
