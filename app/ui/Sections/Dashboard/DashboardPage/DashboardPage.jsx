import React, { useMemo, useState } from 'react'
import { Alert, App, Grid, Skeleton, Typography } from 'antd'
import { useQuery, useSubscription } from '@apollo/client/react'

import AddWidgetModal from '../AddWidget/AddWidgetModal'
import EditBar, { EditNotice } from '../EditBar/EditBar'
import Section from '../Section/Section'
import EditableSections from './EditableSections'
import useDebouncedCounter from '../utils/useDebouncedCounter'
import useNow from '../utils/useNow'
import useFleetLiveUpdates from '../../../utils/useFleetLiveUpdates'
import { StreamVisibilityProvider } from '../utils/useStreamWhenVisible'
import {
  DASHBOARD_CHANGED,
  DASHBOARD_PAGE,
  MONITOR_HEALTHY
} from '../graphql/dashboard'
import useLayoutEditor from './useLayoutEditor'

const MONITOR_POLL_INTERVAL = 15000
// Queue widgets reload their lists this long after the last queue change
const QUEUE_RELOAD_DELAY = 500

const CHANGED_ELSEWHERE = 'Someone saved the dashboard on another screen while you were editing. Your changes are ' +
  'kept, and Done saves them over it.'

const HEADER = { display: 'flex', flexWrap: 'wrap', gap: 12, alignItems: 'center', justifyContent: 'space-between' }

const plural = (count, one, many) => `${count} ${count === 1 ? one : many}`

// "4 printers · 1 printing · 5 jobs queued"
export function summary (printers) {
  const printing = printers.filter((printer) => printer.status.stateFamily === 'PRINTING').length
  const queued = printers.reduce((total, printer) => total + printer.queuedCount, 0)
  return [plural(printers.length, 'printer', 'printers'), `${printing} printing`,
    plural(queued, 'job queued', 'jobs queued')].join(' · ')
}

// The dashboard, at /. One query loads the layout and every printer; pushes keep them live, and reloads catch up on missed pushes.
// Edit mode arranges a draft of the layout (useLayoutEditor) and saves it on Done. It needs the 4-column grid, so
// it's for desktop screens (md and up) only.
export default function DashboardPage () {
  // cache-and-network: coming back to the page never shows (and acts on) statuses cached earlier
  const { data, error, refetch } = useQuery(DASHBOARD_PAGE, { fetchPolicy: 'cache-and-network' })
  // no-cache: the page query's own monitorHealthy can't overwrite a failed poll
  const monitor = useQuery(MONITOR_HEALTHY, { pollInterval: MONITOR_POLL_INTERVAL, fetchPolicy: 'no-cache' })
  const editor = useLayoutEditor(data?.dashboard)
  const { noticeChange } = editor
  const desktop = !!Grid.useBreakpoint().md
  // Each queue push refreshes its printer's queuedCount, nextJob and canStartNext; queueVersion tells queue widgets
  // to reload their lists, once per burst of changes
  const [queueVersion, queueChanged] = useDebouncedCounter(QUEUE_RELOAD_DELAY)
  useFleetLiveUpdates(refetch, { onQueueChange: queueChanged })
  useSubscription(DASHBOARD_CHANGED, {
    onData: ({ client, data: pushed }) => {
      const dashboard = pushed.data?.dashboardChanged
      if (!dashboard) return
      let unknownPrinter = false
      client.cache.updateQuery({ query: DASHBOARD_PAGE }, (page) => {
        if (!page) return page
        const known = new Set(page.printers.map((printer) => printer.id))
        unknownPrinter = dashboard.sections.some((section) => section.widgets.some(
          (widget) => widget.printer && !known.has(widget.printer.id)
        ))
        return { ...page, dashboard }
      })
      if (unknownPrinter) refetch() // a printer added since the page loaded
      noticeChange()
    }
  })
  const now = useNow()
  const [gallery, setGallery] = useState(false)

  const printers = data?.printers
  const printersById = useMemo(
    () => Object.fromEntries((printers || []).map((printer) => [printer.id, printer])),
    [printers]
  )

  if (error && !data) return <Alert type="error" title="Could not load the dashboard" description={error.message} />
  if (!data) return <Skeleton active />

  // Live: the last reloads worked and the monitor is reporting. Otherwise the controls warn that states may be old.
  const unreachable = !!(error || monitor.error)
  const live = !unreachable && (monitor.data?.monitorHealthy ?? data.monitorHealthy)
  // Cameras never stream in edit mode
  const widgetData = { printers, printersById, now, live, queueVersion, editing: editor.editing }
  // An untitled first section with no widgets has nothing to show
  const sections = data.dashboard.sections.filter((section) => section.title || section.widgets.length > 0)
  return (
    <App>
      <StreamVisibilityProvider>
        <div style={HEADER}>
          <div>
            <Typography.Title level={3} style={{ margin: 0 }}>Dashboard</Typography.Title>
            <Typography.Text style={{ color: 'rgba(0, 0, 0, 0.65)' }}>{summary(printers)}</Typography.Text>
          </div>
          <EditBar editing={editor.editing} busy={editor.busy} onEdit={desktop ? editor.start : undefined} onReset={editor.reset}
            onAddDivider={() => editor.dispatch({ type: 'addDivider' })} onAddWidget={() => setGallery(true)}
            onDone={editor.done} />
        </div>
        {editor.editing && <EditNotice />}
        {editor.editing && editor.changedElsewhere && (
          <Alert type="warning" showIcon style={{ marginTop: 16 }} title="Layout changed elsewhere"
            description={CHANGED_ELSEWHERE} />
        )}
        {editor.problem && (
          <Alert type="error" showIcon style={{ marginTop: 16 }} title={editor.problem.title}
            description={editor.problem.messages.map((message) => <div key={message}>{message}</div>)} />
        )}
        {!live && (
          <Alert type="warning" showIcon style={{ marginTop: 16 }} title="Live data paused"
            description={unreachable
              ? "Tentacles can't be reached, so printer states may be out of date."
              : "The printer monitor isn't reporting, so printer states may be out of date."} />
        )}
        {/* Nothing changes the draft while it saves or resets */}
        <div inert={!!editor.busy} aria-busy={!!editor.busy}>
          {editor.editing
            ? <EditableSections editor={editor} data={widgetData} />
            : sections.map((section, index) => (
              <Section key={section.id || index} section={section} index={index} data={widgetData} />
            ))}
        </div>
        <AddWidgetModal open={editor.editing && gallery} printers={printers} dispatch={editor.dispatch}
          onClose={() => setGallery(false)} />
      </StreamVisibilityProvider>
    </App>
  )
}
