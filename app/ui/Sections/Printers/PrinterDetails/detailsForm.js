// The details page's one form: its values for a saved printer, and what Save Changes sends. The About This
// Printer card adds its fields to both.

// Username is PrusaLink's only
const connectionFields = (backend) => backend === 'PRUSALINK' ? ['name', 'uri', 'username'] : ['name', 'uri']

// The secret is never shown: its field starts blank
export const formValues = (printer) => ({
  name: printer.name,
  uri: printer.uri || '',
  username: printer.username || '',
  secret: ''
})

// updatePrinter's input, without the id: each field that differs from the saved printer (the others are omitted,
// so they stay as they are), and the secret only when one was typed (blank keeps the saved one)
export function updateInput (printer, values = {}) {
  const saved = formValues(printer)
  const input = {}
  connectionFields(printer.backend).forEach((field) => {
    if (values[field] !== undefined && values[field] !== saved[field]) input[field] = values[field]
  })
  if (values.secret) input.secret = values.secret
  return input
}

export const hasChanges = (printer, values) => Object.keys(updateInput(printer, values)).length > 0
