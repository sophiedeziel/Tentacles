import React, { useState, useRef } from 'react'
import { useMatch } from 'react-router'
import Editor from '@monaco-editor/react'
import ReactMarkdown from 'react-markdown'
import { useQuery, useMutation } from '@apollo/client'
import File from './graphql/File.graphql'
import UpdateFile from './graphql/UpdateFile.graphql'
import GcodeDocs from './GcodeDocs/GcodeDocs.json'
import { GCodeViewer } from 'react-gcode-viewer'

import { Card, Collapse, Col, Row, Button, Typography, Divider, Input } from 'antd'
import { PageHeader } from '@ant-design/pro-layout'
import { FileOutlined } from '@ant-design/icons'

import GCodeAnalysis from './components/GCodeAnalysis.jsx'
import gcodeDefinition from './../../../common/gcodeDefinition.js'
import GitHubLight from 'monaco-themes/themes/GitHub Light.json'

const { Title } = Typography
const { Search } = Input

export default function FileEditor () {
  const match = useMatch('/files/:id')
  const fileID = match.params.id

  const editorRef = useRef(null)
  const [lineContent, setLineContent] = useState()
  const [filename, setFilename] = useState(null)
  const [jumptoLine, setJumptoLine] = useState(1)

  const [updateFile] = useMutation(UpdateFile)

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

  function handleEditorWillMount (monaco) {
    // here is the monaco instance
    // do something before editor is mounted
    monaco.languages.register({ id: 'gcode' })
    monaco.languages.setMonarchTokensProvider('gcode', gcodeDefinition)
    monaco.editor.defineTheme('GitHubLight', GitHubLight)
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
          fileContent: editorRef.current.getValue(),
          fileName: filename || file.filename
        }
      }
    }
    )
  }

  const onSearch = (event) => {
    const command = event.target.value.toUpperCase()
    if (GcodeDocs[command]) {
      setLineContent(command)
    } else {
      // Search in documentation text
    }
  }

  const uriTransformer = (text) => {
    return (null)
  }

  const ContextualDocumentation = () => {
    if (!GcodeDocs[lineContent]) {
      return (null)
    }

    const { structuredDoc, mdDescription } = GcodeDocs[lineContent]
    const { parameters, title, notes, devnotes, examples } = structuredDoc

    return (
      <>
        <Title level={2}>{lineContent + ' : ' + title}</Title>
        { parameters &&
        <code>
          {
            parameters.filter((value) => value) && lineContent
          }
          {
            parameters.filter((value) => value)?.map(({ tag, optional, values }) => (
              <span key={tag}>
                {' '}
                {optional && '['}
                {tag}
                {values?.map(({ tag }, index) => (
                  <span key={tag + index}>{`<${tag}>`}</span>
                ))}
                {optional && ']'}
              </span>
            ))
          }
        </code>
        }
        <Divider />
        <Title level={3}>Description</Title>
        <ReactMarkdown urlTransform={uriTransformer}>
          { mdDescription }
        </ReactMarkdown>

        { notes &&
          <>
            <Title level={3}>Notes</Title>
            { typeof (notes) === 'object' &&
              <ReactMarkdown urlTransform={uriTransformer}>
                {notes.map(
                  (note) => (
                    `- ${note}`
                  )).join('\r\n')}
              </ReactMarkdown>
            }
            { typeof (notes) === 'string' &&
              <ReactMarkdown urlTransform={uriTransformer}>
                {notes}
              </ReactMarkdown>
            }

          </>
        }

        { devnotes &&
          <>
            <Title level={3}>Developer notes</Title>
            <ReactMarkdown urlTransform={uriTransformer}>
              {devnotes}
            </ReactMarkdown>
          </>
        }

        { parameters &&
          <>
            <Title level={3}>Parameters</Title>
            {
              parameters.filter((value) => value)?.map(({ tag, optional, values, description }) => (
                <p key={tag}>
                  <span>
                    {' '}
                    {optional && '['}
                    {tag}
                    {values?.map(({ tag }, index) => (
                      <span key={index}>{`<${tag}>`}</span>
                    ))}
                    {optional && ']'}
                    {' '}
                  </span>
                  {description}
                </p>
              ))
            }
          </>
        }

        { examples &&
        <>
          <Title level={3}>Examples</Title>
          {

          examples.map(
            ({ pre, post, code }, index) => (
                <div key={index}>
                  { typeof (pre) === 'object' &&
                    <ReactMarkdown urlTransform={uriTransformer}>
                      {pre.map(
                        (item) => (
                          `${item}`
                        )).join('\r\n')}
                    </ReactMarkdown>
                  }
                  { typeof (pre) === 'string' &&
                    <ReactMarkdown urlTransform={uriTransformer}>
                      {pre}
                    </ReactMarkdown>
                  }

                  { typeof (code) === 'object' &&
                    <code>
                      {code.map(
                        (item) => (
                          `${item}`
                        )).join('\r\n')}
                    </code>
                  }

                  { typeof (code) === 'string' &&
                    <code>
                      {code}
                    </code>
                  }

                  { typeof (post) === 'object' &&
                    <ReactMarkdown urlTransform={uriTransformer}>
                      {post.map(
                        (item) => (
                          `${item}`
                        )).join('\r\n')}
                    </ReactMarkdown>
                  }
                  { typeof (post) === 'string' &&
                    <ReactMarkdown urlTransform={uriTransformer}>
                      {post}
                    </ReactMarkdown>
                  }
                  <Divider />
                </div>
            )
          )
          }
        </>
        }
      </>
    )
  }

  const items = [
    {
      key: '1',
      label: 'Preview',
      children: <GCodeViewer
      orbitControls
      showAxes
      quality={0.2}
      floorProps={{
        gridWidth: 300,
        gridLength: 300
      }}
      style={{
        top: 0,
        left: 0,
        width: '100%',
        height: '25%'
      }}
      url={file.downloadUrl}
  />
    },
    {
      key: '2',
      label: 'Documentation',
      children:
      <>
        <Search placeholder="Serach a gocde command" allowClear onChange={onSearch} rootStyle={{ width: 400 }} />
        <Divider />
        <ContextualDocumentation />
      </>
    },
    {
      key: '3',
      label: 'Code analysis',
      children: <GCodeAnalysis gcodeAnalysis={file.gcodeAnalysis} onLineSelect={ (num) => { setJumptoLine(num) }} />
    }
  ]

  return (<>
    <PageHeader
    className="site-page-header"
    ghost={false}
    onBack={() => window.history.back()}
    title="GCode editor"
    >

    </PageHeader>
    <Row gutter={16}>
      <Col span={16}>
        <Card
        title={<Input onChange={(e) => setFilename(e.target.value)} prefix={<FileOutlined />} defaultValue={file.filename} />}
        extra={[
          <Divider key="0" type="vertical" />,
          <Button key="1" type="primary" onClick={handleSave}>Save</Button>
        ]}
        bodyStyle={{ padding: 0 }}
        >
          <Editor
            height="calc(100vh - 220px)"
            language="gcode"
            theme="GitHubLight"
            path={file.filename}
            defaultValue={file.fileContent}
            onMount={handleEditorMount}
            beforeMount={handleEditorWillMount}
            line={jumptoLine}
            />
        </Card>
      </Col>
      <Col span={8}>
        <Collapse items={items} defaultActiveKey={[1, 2, 3]} style={{ overflow: 'scroll', maxHeight: 'calc(100vh - 164px)' }}/>
      </Col>
    </Row>
  </>)
}
