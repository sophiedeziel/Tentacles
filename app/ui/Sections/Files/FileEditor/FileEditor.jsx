import React, { useState } from 'react'
import { useRouteMatch } from 'react-router'
import Editor from '@monaco-editor/react'
import { useQuery } from '@apollo/client'
import File from './graphql/File.graphql'

export default function FileEditor () {
  const match = useRouteMatch('/files/:id')
  const fileID = match.params.id
  const { loading, error, data: fileData } = useQuery(File, {
    variables: { id: fileID }
  })

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { file } = fileData

  function handleEditorMount (editor) {
    editor.onDidChangeCursorPosition(console.log)
  }

  return (
    <>

      <Editor
        height="90vh"
        defaultLanguage="gcode"
        path={file.filename}
        defaultValue={file.fileContent}
        onMount={handleEditorMount}
      />
    </>
  )
}
