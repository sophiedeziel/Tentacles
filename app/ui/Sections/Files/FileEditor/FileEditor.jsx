import React, { useState, useRef } from 'react'
import { useMatch } from 'react-router'
import Editor from '@monaco-editor/react'
import ReactMarkdown from 'react-markdown'
import { useQuery, useMutation } from '@apollo/client'
import File from './graphql/File.graphql'
import UpdateFile from './graphql/UpdateFile.graphql'
import GcodeDocs from './GcodeDocs/GcodeDocs.json'
import { GCodeViewer } from 'react-gcode-viewer'

import { Card, Collapse, Col, Row, Button, Typography, Drawer, Divider, Input } from 'antd'
import { PageHeader } from '@ant-design/pro-layout'
import { FileOutlined } from '@ant-design/icons'
const { Title } = Typography
const { Search } = Input

export default function FileEditor () {
  const match = useMatch('/files/:id')
  const fileID = match.params.id

  const editorRef = useRef(null)
  const [lineContent, setLineContent] = useState()
  const [visible, setVisible] = useState(false)
  const [filename, setFilename] = useState(null)

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
    console.log(filename || file.filename)
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

  const showDrawer = () => {
    setVisible(true)
  }
  const onClose = () => {
    setVisible(false)
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
                  <ReactMarkdown urlTransform={uriTransformer}>
                    {pre}
                  </ReactMarkdown>
                  <code>
                    {code}
                  </code>
                  <ReactMarkdown urlTransform={uriTransformer}>
                    {post}
                  </ReactMarkdown>
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
    // {
    //   key: '2',
    //   label: 'Documentation',
    //   children: <p>sadf</p>,
    // },
    {
      key: '3',
      label: 'Code analysis',
      children: <p>asdf</p>
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
          <Button key="1" type="secondary" onClick={showDrawer}>Docs</Button>,
          <Button key="2" type="primary" onClick={handleSave}>Save</Button>
        ]}
        bodyStyle={{ padding: 0 }}
        >
          <Editor
            height="calc(100vh - 250px)"
            defaultLanguage="gcode"
            path={file.filename}
            defaultValue={file.fileContent}
            onMount={handleEditorMount}
            />
        </Card>
      </Col>
      <Col span={8}>
        <Collapse items={items} defaultActiveKey={['1', '3']} />
      </Col>
    </Row>
    <Drawer
    mask={false}
    closable={true}
    open={visible}
    size={'large'}
    title={'Documentation'}
    onClose={onClose}
    extra={<Search placeholder="Serach a gocde command" allowClear onChange={onSearch} rootStyle={{ width: 400 }} />}
    >
      <ContextualDocumentation />
    </Drawer>
  </>)
}
