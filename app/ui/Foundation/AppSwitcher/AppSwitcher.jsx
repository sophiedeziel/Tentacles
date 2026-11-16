import React, { Suspense, lazy } from 'react'

import {
  Navigate,
  Routes,
  Route,
  Outlet
} from 'react-router'

const DashboardPage = lazy(() => import('../../Sections/Dashboard/DashboardPage/DashboardPage'))
const PrintersList = lazy(() => import('../../Sections/Printers/PrintersList/PrintersList'))
const PrinterAdd = lazy(() => import('../../Sections/Printers/PrinterAdd/PrinterAdd'))
const PrinterDetails = lazy(() => import('../../Sections/Printers/PrinterDetails/PrinterDetails'))
const QueuesList = lazy(() => import('../../Sections/Printers/QueuesList/QueuesList'))
const Queue = lazy(() => import('../../Sections/Printers/Queue/Queue'))
const FilesList = lazy(() => import('../../Sections/Files/FilesList/FilesList'))
const FileEditor = lazy(() => import('../../Sections/Files/FileEditor/FileEditor'))
const FilePrinter = lazy(() => import('../../Sections/Files/FilePrinter/FilePrinter'))

export default function AppSwithcer () {
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
          <Route path="files" element={<Outlet />} >
            <Route index element={<FilesList />} />
            <Route path=":id" element={<Outlet />} >
              <Route index element={<FileEditor />} />
              <Route path="print" element={<FilePrinter />} />
            </Route>
          </Route>
          {/* <Route path="bye" component={() => {
            window.location.reload()
          }} /> */}
      </Routes>
    </Suspense>
  )
}
