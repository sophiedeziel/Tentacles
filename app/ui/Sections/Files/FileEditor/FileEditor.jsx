import React, { useState } from 'react'
import { useRouteMatch } from 'react-router'
import CodeMirror from '@uiw/react-codemirror'
import { GCodeLanguage } from 'gcode-lang-codemirror'

import { useQuery } from '@apollo/client'
import File from './graphql/File.graphql'

export default function FileEditor () {
  const match = useRouteMatch('/files/:id')
  const fileID = match.params.id
  const [code, setCode] = useState()
  const { loading, error, data: fileData } = useQuery(File, {
    variables: { id: fileID }
  })

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { file } = fileData

  return (
    <>
      <CodeMirror
      value={file.fileContent}
      extensions={[GCodeLanguage()]}
      height="calc(100vh - 190px)"
    />
    </>
  )
}
