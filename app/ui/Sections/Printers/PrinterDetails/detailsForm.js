// The details page's one form: its values for a saved printer, and what Save Changes sends.

// Username is PrusaLink's only
const connectionFields = (backend) => backend === 'PRUSALINK' ? ['name', 'uri', 'username'] : ['name', 'uri']

// The About card's fields sent as they are (the build volume is sent whole, see volumeInput)
const SPEC_FIELDS = [
  'brand', 'model', 'firmware', 'firmwareVersion', 'extruders', 'nozzleDiameter', 'maxHotendTemp', 'maxBedTemp',
  'heatedBed', 'heatedChamber', 'webcam', 'materials'
]

// The build volume's inputs for each bed shape (Z is the height of both)
export const DIMENSIONS = { rectangular: ['x', 'y', 'z'], circular: ['diameter', 'z'] }

// A blank input is no value
const clean = (value) => (value === '' || value === undefined ? null : value)
export const sameValue = (a, b) => JSON.stringify(clean(a)) === JSON.stringify(clean(b))

// The About card's values from a PrinterSpecs (saved or reported; null when not set). The bed shape comes from the
// build volume's type: rectangular when there is none.
export function specsFormValues (specs) {
  const volume = specs.buildVolume || {}
  return {
    brand: specs.brand ?? null,
    model: specs.model ?? null,
    firmware: specs.firmwareDisplayName ?? null,
    firmwareVersion: specs.firmwareVersion ?? null,
    bedShape: volume.diameter != null ? 'circular' : 'rectangular',
    x: volume.x ?? null,
    y: volume.y ?? null,
    z: volume.z ?? volume.height ?? null,
    diameter: volume.diameter ?? null,
    extruders: specs.extruders ?? null,
    nozzleDiameter: specs.nozzleDiameter ?? null,
    maxHotendTemp: specs.maxHotendTemp ?? null,
    maxBedTemp: specs.maxBedTemp ?? null,
    heatedBed: specs.heatedBed ?? null,
    heatedChamber: specs.heatedChamber ?? null,
    webcam: specs.webcam ?? null,
    materials: specs.materials || []
  }
}

// The BuildVolumeInput of the bed shape's dimensions: null when they are all blank, undefined (not sent) while only
// some are filled
export function volumeInput (specs) {
  const values = DIMENSIONS[specs.bedShape].map((dimension) => clean(specs[dimension]))
  if (values.every((value) => value === null)) return null
  if (values.includes(null)) return undefined
  return specs.bedShape === 'circular'
    ? { circular: { diameter: specs.diameter, height: specs.z } }
    : { rectangular: { x: specs.x, y: specs.y, z: specs.z } }
}

// The secret is never shown: its field starts blank
export const formValues = (printer) => ({
  name: printer.name,
  uri: printer.uri || '',
  username: printer.username || '',
  secret: '',
  specs: specsFormValues(printer.specs || {})
})

// PrinterSpecsInput: each field that differs from the saved one (blank clears it), and the build volume once every
// dimension of its shape is filled, or all are cleared
function specsInput (saved, specs) {
  const input = {}
  if (!specs) return input
  SPEC_FIELDS.forEach((field) => {
    if (specs[field] !== undefined && !sameValue(specs[field], saved[field])) input[field] = clean(specs[field])
  })
  const volume = specs.bedShape ? volumeInput(specs) : undefined
  if (volume !== undefined && !sameValue(volume, volumeInput(saved))) input.buildVolume = volume
  return input
}

// updatePrinter's input, without the id: each field that differs from the saved printer (the others are omitted,
// so they stay as they are), and the secret only when one was typed (blank keeps the saved one)
export function updateInput (printer, values = {}) {
  const saved = formValues(printer)
  const input = {}
  connectionFields(printer.backend).forEach((field) => {
    if (values[field] !== undefined && values[field] !== saved[field]) input[field] = values[field]
  })
  if (values.secret) input.secret = values.secret
  const specs = specsInput(saved.specs, values.specs)
  if (Object.keys(specs).length > 0) input.specs = specs
  return input
}

export const hasChanges = (printer, values) => Object.keys(updateInput(printer, values)).length > 0

// The firmwares Tentacles knows (saved as their value); any other text is saved as typed
export const FIRMWARES = [
  { value: 'marlin', label: 'Marlin' },
  { value: 'klipper', label: 'Klipper' },
  { value: 'prusa_firmware', label: 'Prusa Firmware' },
  { value: 'reprapfirmware', label: 'RepRapFirmware' }
]

// The firmware Select's options: the known firmwares, the saved text, and what is being typed when it is new
export function firmwareOptions (value, typed = '') {
  const options = [...FIRMWARES]
  const known = (text) => options.some((option) => [option.value, option.label.toLowerCase()].includes(text.toLowerCase()))
  ;[value, typed.trim()].forEach((text) => {
    if (text && !known(text)) options.push({ value: text, label: text })
  })
  return options
}
