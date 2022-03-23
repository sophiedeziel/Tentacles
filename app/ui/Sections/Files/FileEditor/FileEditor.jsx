import React, { useState } from 'react'
import { useRouteMatch } from 'react-router'
import CodeMirror from '@uiw/react-codemirror'

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
      height="calc(100vh - 190px)"
      onChange={(value, viewUpdate) => {
        console.log('value:', value)
      }}
    />
    <pre>
    {/* {file.fileContent} */}
    </pre>
      {/* <CodeEditor
        value={file.fileContent}
        language="gcode"
        onChange={(evn) => setCode(evn.target.value)}
        padding={15}
        // style={{
        //   fontSize: 12,
        //   fontFamily: 'ui-monospace,SFMono-Regular,SF Mono,Consolas,Liberation Mono,Menlo,monospace'
        // }}
        /> */}
    </>
  )
}
