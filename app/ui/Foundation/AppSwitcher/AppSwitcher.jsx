import React, { Suspense, lazy } from 'react'

import {
  Routes,
  Route,
  Outlet
} from 'react-router-dom'

const Dashboard = lazy(() => import('../../Sections/Dashboard/Dashboard'))
const PrintersList = lazy(() => import('../../Sections/Printers/PrintersList/PrintersList'))
const PrinterAdd = lazy(() => import('../../Sections/Printers/PrinterAdd/PrinterAdd'))
const QueuesList = lazy(() => import('../../Sections/Printers/QueuesList/QueuesList'))
const Queue = lazy(() => import('../../Sections/Printers/Queue/Queue'))
const FilesList = lazy(() => import('../../Sections/Files/FilesList/FilesList'))
const FileEditor = lazy(() => import('../../Sections/Files/FileEditor/FileEditor'))
const FilePrinter = lazy(() => import('../../Sections/Files/FilePrinter/FilePrinter'))

export default function AppSwithcer () {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Routes>
          <Route path="/" element={<Dashboard />}/>
          <Route path="printers" element={<Outlet />}>
            <Route index element={<QueuesList />} />
            <Route path=":id/queue" element={<Queue />} />
            <Route path="manage" element={<PrintersList />} />
            <Route path="add" element={<PrinterAdd />} />
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
