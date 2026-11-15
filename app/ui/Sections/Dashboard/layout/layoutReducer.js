import { REGISTRY, SIZES } from '../widgets/registry'

// The title of a divider added in edit mode
export const NEW_DIVIDER_TITLE = 'New Section'

let fallbackKeys = 0

// A key for React and dnd-kit only, never saved (a new section or widget saves with `id: null`).
// crypto.randomUUID only exists in secure contexts, and Tentacles is often opened over plain http on the LAN.
export function newKey () {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID()
  fallbackKeys += 1
  return `new-${Date.now().toString(36)}-${fallbackKeys}`
}

const withoutTypename = (options) => Object.fromEntries(
  Object.entries(options || {}).filter(([key]) => key !== '__typename')
)

function widgetFrom ({ id, type, widthUnits, heightUnits, printer, options }) {
  return {
    key: id ? `widget-${id}` : newKey(),
    id: id ?? null,
    type,
    widthUnits,
    heightUnits,
    printer: printer ? { id: printer.id } : null,
    options: withoutTypename(options)
  }
}

// The edit-mode copy of a layout (`dashboard` or `defaultDashboard`): its sections, in order, each with a `key`
// that stays the same while it moves. The first section is the untitled one above every divider.
export function draftFrom (dashboard) {
  const sections = dashboard.sections.map((section) => ({
    key: section.id ? `section-${section.id}` : newKey(),
    id: section.id ?? null,
    title: section.title ?? null,
    widgets: section.widgets.map(widgetFrom)
  }))
  if (!sections.length || sections[0].title) sections.unshift({ key: newKey(), id: null, title: null, widgets: [] })
  return sections
}

// Where the widget with `key` is: its section's index and its index in that section (null when it isn't there)
export function locate (sections, key) {
  for (let section = 0; section < sections.length; section++) {
    const index = sections[section].widgets.findIndex((widget) => widget.key === key)
    if (index >= 0) return { section, index }
  }
  return null
}

const sectionIndex = (sections, key) => sections.findIndex((section) => section.key === key)

const replaceAt = (list, index, item) => list.map((existing, at) => (at === index ? item : existing))

function updateWidget (sections, key, update) {
  const at = locate(sections, key)
  if (!at) return sections
  const section = sections[at.section]
  const widget = update(section.widgets[at.index])
  if (!widget) return sections
  return replaceAt(sections, at.section, { ...section, widgets: replaceAt(section.widgets, at.index, widget) })
}

// Moves a widget to `index` in another section or its own. The same state comes back when nothing moves, so a drag
// that hovers in place doesn't re-render.
function moveWidget (sections, key, toSectionKey, index) {
  const from = locate(sections, key)
  const to = sectionIndex(sections, toSectionKey)
  if (!from || to < 0) return sections
  const target = Math.max(0, Math.min(index, sections[to].widgets.length - (from.section === to ? 1 : 0)))
  if (from.section === to && from.index === target) return sections

  const widget = sections[from.section].widgets[from.index]
  const next = sections.map((section) => ({ ...section, widgets: section.widgets.filter((item) => item.key !== key) }))
  next[to].widgets.splice(target, 0, widget)
  return next.map((section, at) => (at === from.section || at === to ? section : sections[at]))
}

// Whether ‹ (-1) or › (+1) can move the widget: across dividers too, but not before the first or after the last
export function canStep (sections, key, step) {
  const at = locate(sections, key)
  if (!at) return false
  if (step < 0) return at.index > 0 || at.section > 0
  return at.index < sections[at.section].widgets.length - 1 || at.section < sections.length - 1
}

// ‹ and ›: one place earlier or later. Past the start or end of its section, the widget crosses the divider, as if
// the dividers were in the same list as the widgets.
function stepWidget (sections, key, step) {
  if (!canStep(sections, key, step)) return sections
  const at = locate(sections, key)
  const length = sections[at.section].widgets.length
  if (step < 0 && at.index === 0) {
    const previous = sections[at.section - 1]
    return moveWidget(sections, key, previous.key, previous.widgets.length)
  }
  if (step > 0 && at.index === length - 1) return moveWidget(sections, key, sections[at.section + 1].key, 0)
  return moveWidget(sections, key, sections[at.section].key, at.index + step)
}

// A widget of `type` at `size`, with that size's default options
export function newWidget (type, size, printerId = null) {
  const entry = REGISTRY[type]
  const { widthUnits, heightUnits } = SIZES[size]
  return {
    key: newKey(), id: null, type, widthUnits, heightUnits,
    printer: printerId ? { id: printerId } : null,
    options: entry.defaultOptions(size)
  }
}

function moveSection (sections, key, index) {
  const from = sectionIndex(sections, key)
  // The untitled first section stays first
  const to = Math.max(1, Math.min(index, sections.length - 1))
  if (from < 1 || from === to) return sections
  const next = sections.filter((section) => section.key !== key)
  next.splice(to, 0, sections[from])
  return next
}

// Removing a divider keeps its widgets: they join the end of the section above
function removeDivider (sections, key) {
  const index = sectionIndex(sections, key)
  if (index < 1) return sections
  const above = sections[index - 1]
  const merged = { ...above, widgets: [...above.widgets, ...sections[index].widgets] }
  return sections.filter((section) => section.key !== key).map((section) => (section === above ? merged : section))
}

// The edit-mode draft (an array of sections, see draftFrom). Every edit changes only the draft; Done saves it.
// - load { dashboard }: start over from a layout (Edit Dashboard, or Reset Layout with the default layout)
// - restore { sections }: back to a snapshot (a cancelled drag)
// - moveWidget { key, sectionKey, index }, stepWidget { key, step }
// - resizeWidget { key, size }: only to a size the widget's type supports; its options are kept for every size
// - setPrinter { key, printerId }, setOption { key, option, value }
// - addWidget { widgetType, size, printerId }: at the end of the last section; removeWidget { key }
// - addDivider, renameDivider { key, title }, stepDivider { key, step }, moveSection { key, index },
//   removeDivider { key }
export default function layoutReducer (sections, action) {
  switch (action.type) {
    case 'load':
      return draftFrom(action.dashboard)
    case 'restore':
      return action.sections
    case 'moveWidget':
      return moveWidget(sections, action.key, action.sectionKey, action.index)
    case 'stepWidget':
      return stepWidget(sections, action.key, action.step)
    case 'resizeWidget':
      return updateWidget(sections, action.key, (widget) => (
        REGISTRY[widget.type]?.sizes.includes(action.size)
          ? { ...widget, widthUnits: SIZES[action.size].widthUnits, heightUnits: SIZES[action.size].heightUnits }
          : null
      ))
    case 'setPrinter':
      return updateWidget(sections, action.key, (widget) => ({
        ...widget, printer: action.printerId ? { id: action.printerId } : null
      }))
    case 'setOption':
      return updateWidget(sections, action.key, (widget) => ({
        ...widget, options: { ...widget.options, [action.option]: action.value }
      }))
    case 'addWidget': {
      const last = sections[sections.length - 1]
      const widget = newWidget(action.widgetType, action.size, action.printerId)
      return replaceAt(sections, sections.length - 1, { ...last, widgets: [...last.widgets, widget] })
    }
    case 'removeWidget':
      return sections.map((section) => (
        section.widgets.some((widget) => widget.key === action.key)
          ? { ...section, widgets: section.widgets.filter((widget) => widget.key !== action.key) }
          : section
      ))
    case 'addDivider':
      return [...sections, { key: newKey(), id: null, title: NEW_DIVIDER_TITLE, widgets: [] }]
    case 'renameDivider':
      return sections.map((section) => (section.key === action.key ? { ...section, title: action.title } : section))
    case 'stepDivider':
      return moveSection(sections, action.key, sectionIndex(sections, action.key) + action.step)
    case 'moveSection':
      return moveSection(sections, action.key, action.index)
    case 'removeDivider':
      return removeDivider(sections, action.key)
    default:
      throw new Error(`Unknown layout action: ${action.type}`)
  }
}
