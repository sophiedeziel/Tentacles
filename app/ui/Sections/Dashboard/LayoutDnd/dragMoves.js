import { closestCenter, pointerWithin } from '@dnd-kit/core'

import { locate } from '../layout/layoutReducer'

// What can be dragged and dropped on (each droppable's data.type):
// - 'widget': a widget, sortable in its section (id: the widget's key)
// - 'end': the tile at the end of a section, where a widget joins it last (data.sectionKey)
// - 'section': a divider with its widgets, sortable among the sections (id: the section's key)
const typeOf = (item) => item?.data.current?.type

// Where a widget dropped on `over` goes: { sectionKey, index }, or null
function widgetTarget (sections, over) {
  if (typeOf(over) === 'end') {
    const section = sections.find((candidate) => candidate.key === over.data.current.sectionKey)
    return section ? { sectionKey: section.key, index: section.widgets.length } : null
  }
  if (typeOf(over) === 'widget') {
    const at = locate(sections, over.id)
    return at ? { sectionKey: sections[at.section].key, index: at.index } : null
  }
  return null
}

// While dragging, a widget moves in the draft as soon as it is over another widget or a section's end, in its own
// section or another one: the grid reflows live with every widget at its real size, so it shows the result of
// letting go. (A sorting strategy's preview can only shift widgets onto each other's places, which overlaps widgets
// of different sizes.)
export function dragOverAction (sections, active, over) {
  if (typeOf(active) !== 'widget' || over?.id === active.id) return null
  const target = widgetTarget(sections, over)
  return target ? { type: 'moveWidget', key: active.id, ...target } : null
}

// The drop: the layout action it makes, or null when it makes none
export function dragEndAction (sections, active, over) {
  if (!over) return null
  if (typeOf(active) === 'section') {
    const index = sections.findIndex((section) => section.key === over.id)
    return index < 0 ? null : { type: 'moveSection', key: active.id, index }
  }
  const target = widgetTarget(sections, over)
  return target ? { type: 'moveWidget', key: active.id, ...target } : null
}

// A widget only lands on widgets and section ends (the one under the pointer first), a section only on sections
export function collisions (args) {
  const type = typeOf(args.active)
  const droppableContainers = args.droppableContainers.filter((container) => (
    type === 'section' ? typeOf(container) === 'section' : typeOf(container) !== 'section'
  ))
  const scoped = { ...args, droppableContainers }
  if (type === 'widget' && args.pointerCoordinates) {
    const hits = pointerWithin(scoped)
    if (hits.length > 0) return hits
  }
  return closestCenter(scoped)
}
