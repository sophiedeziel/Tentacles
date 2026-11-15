import { REGISTRY } from '../widgets/registry'

// A widget's options as saveDashboard takes them: one-of input keyed by the widget's type ({ printer: {...} } or
// { printQueue: {...} }), with only the options that type declares. An option left out takes its default.
function optionsInput (widget) {
  const entry = REGISTRY[widget.type]
  const values = Object.fromEntries(
    entry.optionKeys
      .filter((key) => typeof widget.options[key] === 'boolean')
      .map((key) => [key, widget.options[key]])
  )
  return { [entry.optionsInput]: values }
}

// The draft (see layoutReducer) as saveDashboard's `sections` input. Saved sections and widgets send their id (and
// are updated), new ones send null (and are created); anything missing is destroyed. Keys stay in the browser.
export default function saveInput (sections) {
  return sections.map((section, index) => ({
    id: section.id,
    // The first section never has a title; a divider's surrounding spaces are dropped
    title: index === 0 ? null : (section.title ?? '').trim(),
    widgets: section.widgets.map((widget) => ({
      id: widget.id,
      type: widget.type,
      widthUnits: widget.widthUnits,
      heightUnits: widget.heightUnits,
      printerId: widget.printer?.id ?? null,
      options: optionsInput(widget)
    }))
  }))
}
