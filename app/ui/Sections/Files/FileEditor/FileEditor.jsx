import React, { useState } from 'react'
import { useRouteMatch } from 'react-router'
import Editor from '@monaco-editor/react'
import { useQuery } from '@apollo/client'
import File from './graphql/File.graphql'

import { Row, Col } from 'antd'

export default function FileEditor () {
  const match = useRouteMatch('/files/:id')
  const fileID = match.params.id

  const [lineNumber, setLineNumber] = useState()
  const [lineContent, setLineContent] = useState()
  const { loading, error, data: fileData } = useQuery(File, {
    variables: { id: fileID }
  })

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { file } = fileData

  function handleEditorMount (editor) {
    editor.onDidChangeCursorPosition((position) => {
      setLineNumber(position.position.lineNumber)
      const model = editor.getModel()
      const content = model.getValueInRange({
        startLineNumber: position.position.lineNumber,
        startColumn: 1,

        endLineNumber: position.position.lineNumber + 1,
        endColumn: 1
      })
      setLineContent(content)
    })
  }

  return (
    <Row>
      <Col span={12}>
      <Editor
        height="90vh"
        defaultLanguage="gcode"
        path={file.filename}
        defaultValue={file.fileContent}
        onMount={handleEditorMount}
      />
      </Col>
      <Col span={12}>
        <pre>{lineNumber}: {lineContent}</pre>
        </Col>
    </Row>

  )
}
