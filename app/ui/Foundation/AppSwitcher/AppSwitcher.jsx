import React, { Suspense, lazy } from 'react'

import {
  Navigate,
  Routes,
  Route,
  Outlet
} from 'react-router'

import useQueueEnabled from '../../Sections/Queue/useQueueEnabled'

const DashboardPage = lazy(() => import('../../Sections/Dashboard/DashboardPage/DashboardPage'))
const PrintersList = lazy(() => import('../../Sections/Printers/PrintersList/PrintersList'))
const PrinterAdd = lazy(() => import('../../Sections/Printers/PrinterAdd/PrinterAdd'))
const PrinterDetails = lazy(() => import('../../Sections/Printers/PrinterDetails/PrinterDetails'))
const QueuesList = lazy(() => import('../../Sections/Printers/QueuesList/QueuesList'))
const Queue = lazy(() => import('../../Sections/Printers/Queue/Queue'))
const FilesList = lazy(() => import('../../Sections/Files/FilesList/FilesList'))
const FileEditor = lazy(() => import('../../Sections/Files/FileEditor/FileEditor'))
const QueuePage = lazy(() => import('../../Sections/Queue/QueuePage'))
const AddToQueuePage = lazy(() => import('../../Sections/Queue/AddToQueue/AddToQueuePage'))
const EditJobPage = lazy(() => import('../../Sections/Queue/AddToQueue/EditJobPage'))
const PrintRedirect = lazy(() => import('../../Sections/Queue/AddToQueue/PrintRedirect'))

export default function AppSwithcer () {
  // The global print queue's pages exist only while its flag is on. Opened directly, they wait for the answer.
  const queue = useQueueEnabled()
  const queuePage = (page) => (queue.enabled ? page : <div>Loading...</div>)

  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Routes>
          <Route path="/" element={<DashboardPage />}/>
          {/* Where the dashboard was served before it replaced the old one: screens may still open it */}
          <Route path="dashboard-next" element={<Navigate to="/" replace />}/>
          <Route path="printers" element={<Outlet />}>
            <Route index element={<QueuesList />} />
            <Route path=":id/queue" element={<Queue />} />
            <Route path="manage" element={<PrintersList />} />
            <Route path="add" element={<PrinterAdd />} />
            <Route path=":id" element={<PrinterDetails />} />
          </Route>
          {(queue.enabled || queue.loading) && (
            <Route path="queue" element={<Outlet />}>
              <Route index element={queuePage(<QueuePage />)} />
              <Route path="add/:fileId" element={queuePage(<AddToQueuePage />)} />
              <Route path=":printJobId/edit" element={queuePage(<EditJobPage />)} />
            </Route>
          )}
          <Route path="files" element={<Outlet />} >
            <Route index element={<FilesList />} />
            <Route path=":id" element={<Outlet />} >
              <Route index element={<FileEditor />} />
              {/* The old print page's address: files, bookmarks and links may still open it */}
              <Route path="print" element={<PrintRedirect />} />
            </Route>
          </Route>
          {/* <Route path="bye" component={() => {
            window.location.reload()
          }} /> */}
      </Routes>
    </Suspense>
  )
}
