import PrinterTile from './Printer/PrinterTile'
import PrinterWidget from './Printer/PrinterWidget'
import PrintQueueTile from './PrintQueue/PrintQueueTile'
import PrintQueueWidget from './PrintQueue/PrintQueueWidget'

// S to XXL are UI names for a widget's span; the API stores widthUnits and heightUnits
export const SIZES = {
  S: { label: 'Small', widthUnits: 1, heightUnits: 1 },
  M: { label: 'Medium', widthUnits: 2, heightUnits: 1 },
  L: { label: 'Large', widthUnits: 2, heightUnits: 2 },
  XL: { label: 'Extra Large', widthUnits: 4, heightUnits: 2 },
  XXL: { label: 'Extra Extra Large', widthUnits: 4, heightUnits: 4 }
}

// The size name of a span, or null when no size has that span
export function sizeOf ({ widthUnits, heightUnits }) {
  return Object.keys(SIZES).find((size) => (
    SIZES[size].widthUnits === widthUnits && SIZES[size].heightUnits === heightUnits
  )) || null
}

// One entry per option: its label, the sizes that show it and an optional hint for the gear menu
const PRINTER_OPTIONS = [
  { key: 'camera', label: 'Camera', sizes: ['M', 'L', 'XL'], hint: { M: 'The stream fills the tile' } },
  { key: 'timeLeft', label: 'Time left', sizes: ['S', 'M', 'L', 'XL'] },
  { key: 'temperatures', label: 'Temperatures', sizes: ['M', 'L', 'XL'] },
  { key: 'upNext', label: 'Up next', sizes: ['L', 'XL'] },
  { key: 'controls', label: 'Controls', sizes: ['L', 'XL'], hint: 'Pause, Resume, Cancel; each asks first' }
]

const PRINT_QUEUE_OPTIONS = [
  { key: 'nowPrinting', label: 'Now printing', sizes: ['M', 'L', 'XL', 'XXL'] },
  { key: 'startNext', label: 'Start Next', sizes: ['L', 'XL', 'XXL'], hint: 'Asks before it starts a print' },
  { key: 'rowPerPrinter', label: 'One row per printer', sizes: ['XL', 'XXL'], allPrintersOnly: true },
  { key: 'history', label: 'History', sizes: ['XL', 'XXL'] }
]

const optionsFor = (options) => (size) => options.filter((option) => option.sizes.includes(size))

// Every widget type the dashboard knows. The frame, the gear menu and the Add Widget gallery read from here, so a
// new widget type is one new entry.
// - sizes / defaultSize: the size names it supports
// - optionsFor(size): the options that size shows; defaultOptions(size): the options of a new widget
// - optionKeys: every option it saves; optionsInput: its key in saveDashboard's one-of options input
// - Component: renders a widget of the layout from the dashboard's data ({ widget, size, data })
// - Preview: the presentational widget, for fixture data (the gallery)
// - SettingsForm: the gear menu's form (edit mode)
export const REGISTRY = {
  PRINTER: {
    name: 'Printer',
    sizes: ['S', 'M', 'L', 'XL'],
    defaultSize: 'L',
    optionsFor: optionsFor(PRINTER_OPTIONS),
    // The camera starts off at Medium, where it would hide the ring
    defaultOptions: (size) => ({
      camera: size === 'L' || size === 'XL', timeLeft: true, temperatures: true, upNext: true, controls: true
    }),
    optionKeys: PRINTER_OPTIONS.map((option) => option.key),
    optionsInput: 'printer',
    Component: PrinterTile,
    Preview: PrinterWidget,
    SettingsForm: null
  },
  PRINT_QUEUE: {
    name: 'Print Queue',
    sizes: ['S', 'M', 'L', 'XL', 'XXL'],
    defaultSize: 'L',
    optionsFor: optionsFor(PRINT_QUEUE_OPTIONS),
    defaultOptions: () => ({ nowPrinting: true, startNext: true, rowPerPrinter: false, history: false }),
    optionKeys: PRINT_QUEUE_OPTIONS.map((option) => option.key),
    optionsInput: 'printQueue',
    Component: PrintQueueTile,
    Preview: PrintQueueWidget,
    SettingsForm: null
  }
}
