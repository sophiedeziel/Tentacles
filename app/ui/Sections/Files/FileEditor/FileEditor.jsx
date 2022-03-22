import React, { useState } from 'react'
import CodeEditor from '@uiw/react-textarea-code-editor'

import { useQuery } from '@apollo/client'
// import File from './graphql/File.graphql'

export default function FileEditor () {
  const [code, setCode] = useState()
  // const { loading, error, data: fileData } = useQuery(File)

  // if (error) return (<>Error!{error.message}</>)

  // if (loading) return (<>Loading</>)

  // const { file } = fileData

  return (
    <>
      <div className="w-tc-editor-var"> </div>
      <CodeEditor
        value={code}
        language="gcode"
        placeholder="; Loading"
        onChange={(evn) => setCode(evn.target.value)}
        padding={15}
        style={{
          fontSize: 12,
          fontFamily: 'ui-monospace,SFMono-Regular,SF Mono,Consolas,Liberation Mono,Menlo,monospace'
        }}
        />
    </>
  )
}
