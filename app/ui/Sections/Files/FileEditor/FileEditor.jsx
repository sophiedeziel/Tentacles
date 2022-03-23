import React, { useState, useRef } from 'react'
import { useRouteMatch } from 'react-router'
import Editor from '@monaco-editor/react'
import { useQuery, useMutation } from '@apollo/client'
import File from './graphql/File.graphql'
import UpdateFile from './graphql/UpdateFile.graphql'

import { Button, PageHeader } from 'antd'

export default function FileEditor () {
  const match = useRouteMatch('/files/:id')
  const fileID = match.params.id

  const editorRef = useRef(null)
  // const [lineNumber, setLineNumber] = useState()
  // const [lineContent, setLineContent] = useState()
  const [setLineNumber] = useState()
  const [setLineContent] = useState()

  const [updateFile] = useMutation(UpdateFile, {
    // update: (cache, { data }) => {
    //   const filesdata = cache.readQuery({ query: Files })

    //   cache.writeQuery({
    //     query: Files,
    //     data: {
    //       files: [...filesdata.files, data.uploadFile.file]
    //     }
    //   })
    // }
  })

  const { loading, error, data: fileData } = useQuery(File, {
    variables: { id: fileID }
  })

  if (error) return (<>Error!{error.message}</>)

  if (loading) return (<>Loading</>)

  const { file } = fileData

  function handleEditorMount (editor) {
    editorRef.current = editor
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

  const handleSave = () => {
    updateFile({
      variables: {
        input: {
          id: fileID,
          fileContent: editorRef.current.getValue()
        }
      }
    }
    )
    console.log(editorRef.current.getValue())
  }

  return (
    <>
      <PageHeader
      className="site-page-header"
      ghost={false}
      onBack={() => window.history.back()}
      title={file.filename}
      >
        <Button type="primary" onClick={handleSave}>Save</Button>
      </PageHeader>
      {/* <Row>
        <Col span={12}> */}
        <Editor
          height="90vh"
          defaultLanguage="gcode"
          path={file.filename}
          defaultValue={file.fileContent}
          onMount={handleEditorMount}
          />
        {/* </Col>
        <Col span={12}>

          <pre>{lineNumber}: {lineContent}</pre>
          </Col>
      </Row> */}
    </>

  )
}
