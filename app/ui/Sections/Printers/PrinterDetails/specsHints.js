import { formatBuildVolume, productName } from '../PrintersList/fleetView'
import { DIMENSIONS, FIRMWARES, sameValue, specsFormValues, volumeInput } from './detailsForm'

const firmwareLabel = (value) => FIRMWARES.find((firmware) => firmware.value === value)?.label || value

// The fields a server can report, and how their reported value reads in "PrusaLink reports …"
const onOff = (value) => (value ? 'on' : 'off')
const FORMATS = {
  name: String,
  model: String,
  firmware: firmwareLabel,
  firmwareVersion: String,
  buildVolume: (volume) => formatBuildVolume(volume.rectangular || volume.circular),
  extruders: String,
  nozzleDiameter: (value) => `${value} mm`,
  heatedBed: onOff,
  heatedChamber: onOff,
  webcam: onOff
}

// What the hints compare, from the form's values (or the reported ones): the name, the specs, and the build volume
// as one value
const hintValues = ({ name, specs = {} }) => ({
  ...specs,
  name,
  buildVolume: specs.bedShape ? volumeInput(specs) ?? null : null
})

// The server's answers in the form's shape: reportedSpecs (a PrinterSpecs, or null) and the name identifyPrinter
// read
export const reportedValues = (reportedSpecs, name) => ({
  name: name ?? null,
  specs: specsFormValues(reportedSpecs || {})
})

// The hint under each field the server reports: "From PrusaLink" when the form holds the reported value, else
// "PrusaLink reports 0.4 mm", both with a reload button. No hint (nor button) for a field the server doesn't report.
export function specsHints (backend, values, reported) {
  if (!values || !reported) return {}
  const product = productName(backend)
  const current = hintValues(values)
  const answers = hintValues(reported)
  const hints = {}
  Object.entries(FORMATS).forEach(([field, format]) => {
    const value = answers[field]
    if (value === null || value === undefined) return
    hints[field] = sameValue(current[field], value) ? `From ${product}` : `${product} reports ${format(value)}`
  })
  return hints
}

// The form values a reload button sets: the reported value of its field (the whole build volume, shape included)
export function reloadedValues (field, reported) {
  if (field === 'name') return { name: reported.name }
  if (field !== 'buildVolume') return { specs: { [field]: reported.specs[field] } }
  const { bedShape } = reported.specs
  const dimensions = Object.fromEntries(DIMENSIONS[bedShape].map((dimension) => [dimension, reported.specs[dimension]]))
  return { specs: { bedShape, ...dimensions } }
}
