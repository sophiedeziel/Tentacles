import React, { useState } from 'react'
import PropTypes from 'prop-types'

import { useMutation } from '@apollo/client/react'

import { Select, Tag } from 'antd'

import LabelFiles from 'graphql/LabelFiles.graphql'
import UnlabelFiles from 'graphql/UnlabelFiles.graphql'
import CreateLabel from 'graphql/CreateLabel.graphql'

export default function LabelApplicator ({ disabled, labels, files, selectedRowKeys }) {
  const [selectedLabels, setSelectedLabels] = useState([])

  const [labelFiles] = useMutation(LabelFiles)
  const [unlabelFiles] = useMutation(UnlabelFiles)
  const [createLabel] = useMutation(CreateLabel, {
    update: (cache, { data }) => {
      const labelsdata = cache.readQuery({ query: 'Files' })

      cache.writeQuery({
        query: 'Files',
        data: {
          files: labelsdata.files,
          labels: {
            __typename: labelsdata.labels.__typename,
            edges: [...labelsdata.labels.edges, { node: data.createLabel.label }]
          }
        }
      })
    }
  })

  const optionRender = ({ data }) => {
    const { name, id, color } = data
    const onPreventMouseDown = (event) => {
      event.preventDefault()
      event.stopPropagation()
    }
    return (
      <>
      { id === name && 'Create: '}
        <Tag
          key={id}
          color={color}
          onMouseDown={onPreventMouseDown}
        >
          {name}
        </Tag>
      </>
    )
  }

  const handleLabelDeselect = (value) => {
    unlabelFiles({ variables: { fileIds: selectedRowKeys, labelIds: [value] } })
  }

  const getSelectedFilesLabels = () => {
    const labelIds = files.filter(file => selectedRowKeys.indexOf(file.id) !== -1).map(file => {
      return file.labels.edges.map(({ node }) => {
        return node.id
      })
    }).reduce((acc, val) => val.filter(e => acc.indexOf(e) !== -1))

    setSelectedLabels(labelIds)
  }

  async function handleLabelSelect (value) {
    if (labels.map(({ node }) => node.id).indexOf(value) === -1) {
      const letters = '0123456789ABCDEF'
      let color = '#'
      for (let i = 0; i < 6; i++) {
        color += letters[Math.floor(Math.random() * 16)]
      }

      const { data } = await createLabel({
        variables: { name: value, color }
      })

      const { createLabel: { label } } = data

      labelFiles({ variables: { fileIds: selectedRowKeys, labelIds: [label.id] } })
      setSelectedLabels([...selectedLabels.splice(selectedLabels.indexOf(value), 1), label.id])
      return
    }
    labelFiles({ variables: { fileIds: selectedRowKeys, labelIds: [value] } })
  }

  return <Select
  value={[...selectedLabels]}
  mode="tags"
  placeholder="Labels"
  style={{
    width: 200
  }}
  options={
    labels.map(({ node }) => {
      return { ...node }
    })
  }
  disabled={disabled}
  optionRender={optionRender}
  tagRender={() => {}}
  fieldNames={{ label: 'name', value: 'id' }}
  showSearch={true}
  filterOption={(input, option) => (option?.name ?? '').includes(input)}
  filterSort={(optionA, optionB) =>
    (optionA?.name ?? '').toLowerCase().localeCompare((optionB?.name ?? '').toLowerCase())
  }
  onChange={setSelectedLabels}
  onFocus={getSelectedFilesLabels}
  onSelect={handleLabelSelect}
  onDeselect={handleLabelDeselect}
/>
}

LabelApplicator.propTypes = {
  disabled: PropTypes.any,
  labels: PropTypes.array,
  files: PropTypes.array,
  selectedRowKeys: PropTypes.array
}
