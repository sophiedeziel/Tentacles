import React, { useState, useRef } from 'react'
import { useRouteMatch } from 'react-router'
import Editor from '@monaco-editor/react'
import ReactMarkdown from 'react-markdown'
import { useQuery, useMutation } from '@apollo/client'
import File from './graphql/File.graphql'
import UpdateFile from './graphql/UpdateFile.graphql'
import GcodeDocs from './GcodeDocs/GcodeDocs.json'

import { Col, Row, Button, PageHeader, Typography } from 'antd'
const { Title } = Typography

export default function FileEditor () {
  const match = useRouteMatch('/files/:id')
  const fileID = match.params.id

  const editorRef = useRef(null)
  const [lineContent, setLineContent] = useState()

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

  function command (line) {
    if (line.startsWith(';')) {
      return null
    }

    return (line.split(' ')[0].replace(/\s+/g, ''))
  }

  function handleEditorMount (editor) {
    editorRef.current = editor
    editor.onDidChangeCursorPosition((position) => {
      const model = editor.getModel()
      const content = model.getValueInRange({
        startLineNumber: position.position.lineNumber,
        startColumn: 1,
        endLineNumber: position.position.lineNumber + 1,
        endColumn: 1
      })

      setLineContent(command(content))
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
  }

  const uriTransformer = (text) => {
    return (null)
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
      <Row gutter={24}>
        <Col span={12}>
        <Editor
          height="calc(100vh - 250px)"
          defaultLanguage="gcode"
          path={file.filename}
          defaultValue={file.fileContent}
          onMount={handleEditorMount}
          />
        </Col>
        <Col span={12}>
          <Title level={2}>{GcodeDocs[lineContent]?.structured_doc?.title}</Title>
          {GcodeDocs[lineContent]?.md_description
            ? (
            <ReactMarkdown transformLinkUri={uriTransformer}>
             { GcodeDocs[lineContent].md_description}
            </ReactMarkdown>
              )
            : ''
          }

          </Col>
      </Row>
    </>

  )
}
