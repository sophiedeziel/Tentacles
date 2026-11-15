import { useReducer, useState } from 'react'
import { useApolloClient } from '@apollo/client/react'

import layoutReducer from '../layout/layoutReducer'
import saveInput from '../layout/saveInput'
import { DASHBOARD_PAGE, DEFAULT_DASHBOARD, SAVE_DASHBOARD } from '../graphql/dashboard'

const NOT_SAVED = "The layout wasn't saved"

// Edit mode: Edit Dashboard copies the saved layout into a draft, every edit changes only the draft, and Done
// saves it with one mutation. Reset Layout loads the default layout into the draft (saved only by Done too).
// - sections / dispatch: the draft and its layoutReducer
// - busy: 'reset' or 'save' while one runs; problem: { title, messages } when the last one failed
export default function useLayoutEditor (dashboard) {
  const client = useApolloClient()
  const [editing, setEditing] = useState(false)
  const [sections, dispatch] = useReducer(layoutReducer, null)
  const [busy, setBusy] = useState(null)
  const [problem, setProblem] = useState(null)

  const start = () => {
    dispatch({ type: 'load', dashboard })
    setProblem(null)
    setEditing(true)
  }

  const reset = async () => {
    setBusy('reset')
    setProblem(null)
    try {
      const { data } = await client.query({ query: DEFAULT_DASHBOARD, fetchPolicy: 'no-cache' })
      dispatch({ type: 'load', dashboard: data.defaultDashboard })
    } catch (error) {
      setProblem({ title: 'Could not load the default layout', messages: [error.message] })
    } finally {
      setBusy(null)
    }
  }

  const done = async () => {
    setBusy('save')
    setProblem(null)
    try {
      const { data } = await client.mutate({ mutation: SAVE_DASHBOARD, variables: { sections: saveInput(sections) } })
      const { dashboard: saved, errors } = data.saveDashboard
      if (errors.length > 0) {
        setProblem({ title: NOT_SAVED, messages: errors })
        return
      }
      client.cache.updateQuery({ query: DASHBOARD_PAGE }, (page) => page && { ...page, dashboard: saved })
      setEditing(false)
    } catch (error) {
      setProblem({ title: NOT_SAVED, messages: [error.message] })
    } finally {
      setBusy(null)
    }
  }

  return { editing, sections, dispatch, busy, problem, start, reset, done }
}
