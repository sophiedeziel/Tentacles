import React, { Suspense, lazy } from 'react'

import {
  Switch,
  Route
} from 'react-router-dom'

const PrintersList = lazy(() => import('../../Sections/Printers/PrintersList/PrintersList'))
const FilesList = lazy(() => import('../../Sections/Files/FilesList/FilesList'))

export default function AppSwithcer () {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Switch>
          <Route path="/printers" exact component={PrintersList} />
          <Route path="/files" exact component={FilesList} />
          <Route path="/" exact>
            <h1>Accueil</h1>
          </Route>
          <Route path="/bye" component={() => {
            window.location.reload()
          }} />
      </Switch>
    </Suspense>
  )
}
