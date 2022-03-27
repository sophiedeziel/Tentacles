import React, { Suspense, lazy } from 'react'

import {
  Switch,
  Route
} from 'react-router-dom'

const Dashboard = lazy(() => import('../../Sections/Dashboard/Dashboard'))
const PrintersList = lazy(() => import('../../Sections/Printers/PrintersList/PrintersList'))
const FilesList = lazy(() => import('../../Sections/Files/FilesList/FilesList'))
const FileEditor = lazy(() => import('../../Sections/Files/FileEditor/FileEditor'))

export default function AppSwithcer () {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Switch>
          <Route path="/printers" exact component={PrintersList} />
          <Route path="/files" exact component={FilesList} />
          <Route path="/files/:fileId" component={FileEditor} />
          <Route path="/" exact component={Dashboard}/>
          <Route path="/bye" component={() => {
            window.location.reload()
          }} />
      </Switch>
    </Suspense>
  )
}
