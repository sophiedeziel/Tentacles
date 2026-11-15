import { useCallback, useReducer, useRef, useState } from 'react'
import { useApolloClient } from '@apollo/client/react'

import layoutReducer from '../layout/layoutReducer'
import saveInput from '../layout/saveInput'
import { DASHBOARD_PAGE, DEFAULT_DASHBOARD, SAVE_DASHBOARD } from '../graphql/dashboard'

const NOT_SAVED = "The layout wasn't saved"
const UNTITLED = 'Every divider needs a title'

// Edit mode: Edit Dashboard copies the saved layout into a draft, every edit changes only the draft, and Done
// saves it with one mutation. Reset Layout loads the default layout into the draft (saved only by Done too).
// - sections / dispatch: the draft and its layoutReducer
// - busy: 'reset' or 'save' while one runs (the draft can't change meanwhile: the page makes it inert);
//   problem: { title, messages } when the last one failed
// - changedElsewhere: another screen saved the layout while editing (noticeChange, on dashboardChanged). The draft
//   stays, and Done still saves over it: the last save wins.
export default function useLayoutEditor (dashboard) {
  const client = useApolloClient()
  const [editing, setEditing] = useState(false)
  const [sections, dispatch] = useReducer(layoutReducer, null)
  const [busy, setBusy] = useState(null)
  const [problem, setProblem] = useState(null)
  const [changedElsewhere, setChangedElsewhere] = useState(false)
  // A push during our own save may be that save's: it only counts if the save fails (a failed save pushes nothing)
  const watching = useRef(null)
  const pushedDuringSave = useRef(false)
  watching.current = editing && (busy === 'save' ? 'saving' : 'editing')
  const noticeChange = useCallback(() => {
    if (watching.current === 'editing') setChangedElsewhere(true)
    if (watching.current === 'saving') pushedDuringSave.current = true
  }, [])
  const notSaved = (messages) => {
    setProblem({ title: NOT_SAVED, messages })
    if (pushedDuringSave.current) setChangedElsewhere(true)
  }

  const start = () => {
    dispatch({ type: 'load', dashboard })
    setProblem(null)
    setChangedElsewhere(false)
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
    if (sections.slice(1).some((section) => !section.title?.trim())) {
      setProblem({ title: NOT_SAVED, messages: [UNTITLED] })
      return
    }
    setBusy('save')
    setProblem(null)
    pushedDuringSave.current = false
    try {
      const { data } = await client.mutate({ mutation: SAVE_DASHBOARD, variables: { sections: saveInput(sections) } })
      const { dashboard: saved, errors } = data.saveDashboard
      if (!saved || errors.length > 0) {
        notSaved(errors.length > 0 ? errors : ['Try again'])
        return
      }
      // A newer layout, pushed from another screen's later save, stays
      client.cache.updateQuery({ query: DASHBOARD_PAGE }, (page) => {
        const cached = page?.dashboard?.updatedAt
        return !page || (cached && saved.updatedAt && cached > saved.updatedAt) ? page : { ...page, dashboard: saved }
      })
      setChangedElsewhere(false)
      setEditing(false)
    } catch (error) {
      notSaved([error.message])
    } finally {
      setBusy(null)
    }
  }

  return { editing, sections, dispatch, busy, problem, changedElsewhere, noticeChange, start, reset, done }
}
