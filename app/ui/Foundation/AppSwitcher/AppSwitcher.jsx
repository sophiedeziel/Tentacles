import React, { Suspense, lazy } from 'react'

import {
  Switch,
  Route
} from 'react-router-dom'

const Dashboard = lazy(() => import('../../Sections/Dashboard/Dashboard'))
const PrintersList = lazy(() => import('../../Sections/Printers/PrintersList/PrintersList'))
const QueuesList = lazy(() => import('../../Sections/Printers/QueuesList/QueuesList'))
const FilesList = lazy(() => import('../../Sections/Files/FilesList/FilesList'))
const FileEditor = lazy(() => import('../../Sections/Files/FileEditor/FileEditor'))
const FilePrinter = lazy(() => import('../../Sections/Files/FilePrinter/FilePrinter'))

export default function AppSwithcer () {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Switch>
          <Route path="/printers" exact component={QueuesList} />
          <Route path="/printers/manage" exact component={PrintersList} />
          <Route path="/files" exact component={FilesList} />
          <Route path="/files/:fileId/print" component={FilePrinter} />
          <Route path="/files/:fileId" component={FileEditor} />
          <Route path="/" exact component={Dashboard}/>
          <Route path="/bye" component={() => {
            window.location.reload()
          }} />
      </Switch>
    </Suspense>
  )
}
