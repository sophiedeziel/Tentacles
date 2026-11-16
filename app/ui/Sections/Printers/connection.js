import { CombinedGraphQLErrors } from '@apollo/client'

// How each printer server is entered: Add Printer's manual form and the details page's Connection card
export const BACKENDS = {
  OCTOPRINT: {
    uriLabel: 'OctoPrint address',
    uriPlaceholder: 'http://octopi.local',
    secretLabel: 'API key',
    secretPlaceholder: 'Paste the key',
    secretHelp: 'In OctoPrint: Settings, Application Keys. Create one named Tentacles.',
    savedSecretPlaceholder: 'Leave blank to keep the current API key',
    savedSecretHelp: 'The saved API key is never shown. In OctoPrint: Settings, Application Keys.',
    wrongSecret: 'Wrong API key'
  },
  PRUSALINK: {
    uriLabel: 'Address',
    uriPlaceholder: 'http://192.168.1.42',
    secretLabel: 'Password',
    secretHelp: 'Shown on the printer: Settings, Network, PrusaLink',
    savedSecretPlaceholder: 'Leave blank to keep the current password',
    savedSecretHelp: 'The saved password is never shown. Find it on the printer: Settings, Network, PrusaLink.',
    wrongSecret: 'Wrong password'
  }
}

// identifyPrinter's failures are GraphQL errors with a code in `extensions.code`
export const testErrorAlert = (error, backend) => {
  const graphQLError = CombinedGraphQLErrors.is(error) ? error.errors[0] : null
  const description = graphQLError?.message || error.message

  switch (graphQLError?.extensions?.code) {
    case 'UNAUTHORIZED': return { title: BACKENDS[backend].wrongSecret, description }
    case 'UNREACHABLE': return { title: 'Printer not reachable', description }
    default: return { title: description }
  }
}
