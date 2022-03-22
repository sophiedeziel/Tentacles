import React from 'react'

import { useQuery } from '@apollo/client'
// import File from './graphql/File.graphql'

export default function FileEditor () {
  // const { loading, error, data: fileData } = useQuery(File)

  // if (error) return (<>Error!{error.message}</>)

  // if (loading) return (<>Loading</>)

  // const { file } = fileData

  return (
    <pre>
      File.
      {/* {file.content} */}
    </pre>
  )
}
