import React, { useMemo, useState } from 'react'
import PropTypes from 'prop-types'
import { gql } from '@apollo/client'
import { useMutation, useQuery } from '@apollo/client/react'
import { useNavigate } from 'react-router'
import fileSize from 'file-size'
import { App, Button, Empty, Input, Modal, Skeleton, Typography, Upload, theme } from 'antd'

import GCODE_SUMMARY_FIELDS from 'graphql/GcodeSummaryFragment.graphql'
import UPLOAD_FILE from 'graphql/UploadFile.graphql'
import { GcodeFileOutlined } from '../../../components/icons'
import * as classes from './FilePickerModal.module.less'

const { Text } = Typography

// The files the queue can print: G-code only (files(gcode: true)), the archived ones left out on this side
export const PICKER_FILES = gql`
  query QueueFilePicker {
    files(gcode: true) {
      id
      filename
      filesize
      createdAt
      isArchived
      isDeleted
      gcodeSummary { ...GcodeSummaryFields }
    }
  }
  ${GCODE_SUMMARY_FIELDS}
`

// The library's files to offer: active G-code files, the latest first, those whose name has `search` in it
export function pickerFiles (files, search = '') {
  const term = search.trim().toLowerCase()
  return files
    .filter((file) => !file.isArchived && !file.isDeleted && file.filename.toLowerCase().includes(term))
    .sort((a, b) => (b.createdAt ?? '').localeCompare(a.createdAt ?? ''))
}

// "PrusaSlicer", "Slicer not recognized" once read; nothing while it is read or when it couldn't be
const slicerText = (summary) => {
  if (summary?.status !== 'READY') return null
  return summary.slicer || 'Slicer not recognized'
}

function FileRow ({ file, selected, onSelect, onOpen }) {
  const { token } = theme.useToken()
  const keyDown = (event) => {
    if (event.key === 'Enter') onOpen(file)
    if (event.key === ' ') {
      event.preventDefault()
      onSelect(file)
    }
  }
  return (
    <li role="option" aria-selected={selected} tabIndex={0} className={classes.row} onClick={() => onSelect(file)}
      onDoubleClick={() => onOpen(file)} onKeyDown={keyDown}
      style={selected ? { background: token.colorPrimaryBg } : undefined}>
      <GcodeFileOutlined aria-hidden style={{ color: token.colorTextSecondary }} />
      <span className={classes.name} title={file.filename}>{file.filename}</span>
      <Text type="secondary" className={classes.small}>
        {[slicerText(file.gcodeSummary), fileSize(file.filesize).human('si')].filter(Boolean).join(' · ')}
      </Text>
    </li>
  )
}

// Upload a File: uploads a G-code file to the library the way the Files page does, then selects it
function UploadButton ({ onUploaded }) {
  const { message } = App.useApp()
  // The library's lists are read again: the Files page's, and this one
  const [uploadFile, { loading }] = useMutation(UPLOAD_FILE, {
    context: { hasUpload: true },
    update: (cache) => { cache.evict({ id: 'ROOT_QUERY', fieldName: 'files' }) }
  })
  const upload = async ({ file, onSuccess, onError }) => {
    try {
      const { data } = await uploadFile({ variables: { input: { fileAttributes: { file, notes: '' } } } })
      onSuccess(file)
      onUploaded(data.uploadFile.file)
    } catch (error) {
      message.error(`Could not upload ${file.name}: ${error.message}`)
      onError(error)
    }
  }
  return (
    <Upload accept=".gcode" showUploadList={false} customRequest={upload}>
      <Button type="link" loading={loading}>Upload a File</Button>
    </Upload>
  )
}

// Add to Queue from the queue page (the FilePicker frame): choose a G-code file, then Continue opens its Add to Queue
// page (/queue/add/:fileId). Upload a File adds one to the library and selects it. `open`, `onClose`: Back to Queue.
export default function FilePickerModal ({ open, onClose }) {
  const { token } = theme.useToken()
  const navigate = useNavigate()
  const [search, setSearch] = useState('')
  const [selectedId, setSelectedId] = useState(null)
  const { data, error, refetch } = useQuery(PICKER_FILES, { skip: !open, fetchPolicy: 'cache-and-network' })

  const files = useMemo(() => pickerFiles(data?.files ?? [], search), [data, search])
  const selected = files.find((file) => file.id === selectedId) ?? null
  const proceed = (file) => navigate(`/queue/add/${file.id}`)
  const uploaded = async (file) => {
    setSearch('')
    await refetch()
    setSelectedId(file.id)
  }

  let list
  if (!data) {
    list = error ? <Text type="danger">Could not load the files: {error.message}</Text> : <Skeleton active />
  } else if (files.length === 0) {
    list = <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={search ? 'No G-code file matches' : 'No G-code files yet'} />
  } else {
    list = (
      <ul role="listbox" aria-label="G-code files" className={classes.list}>
        {files.map((file) => (
          <FileRow key={file.id} file={file} selected={file.id === selectedId}
            onSelect={(each) => setSelectedId(each.id)} onOpen={proceed} />
        ))}
      </ul>
    )
  }

  const footer = (
    <div className={classes.footer}>
      <UploadButton onUploaded={uploaded} />
      <span className={classes.buttons}>
        <Button onClick={onClose}>Back to Queue</Button>
        <Button type="primary" disabled={!selected} onClick={() => proceed(selected)}>
          {selected ? `Continue with ${selected.filename}` : 'Continue'}
        </Button>
      </span>
    </div>
  )

  return (
    <Modal open={open} title="Choose a file to add to the queue" footer={footer} onCancel={onClose} centered
      width={560} destroyOnHidden style={{ '--line': token.colorSplit }}>
      <Input.Search placeholder="Search files" allowClear value={search} aria-label="Search files"
        onChange={(event) => setSearch(event.target.value)} className={classes.search} />
      <div className={classes.box}>{list}</div>
      <Text type="secondary" className={classes.small}>
        Only G-code files are listed. A model has to be sliced before it can be queued.
      </Text>
    </Modal>
  )
}

const fileShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  filename: PropTypes.string.isRequired,
  filesize: PropTypes.number.isRequired,
  gcodeSummary: PropTypes.shape({ status: PropTypes.string, slicer: PropTypes.string })
})

FileRow.propTypes = {
  file: fileShape.isRequired,
  selected: PropTypes.bool.isRequired,
  onSelect: PropTypes.func.isRequired,
  onOpen: PropTypes.func.isRequired
}
UploadButton.propTypes = { onUploaded: PropTypes.func.isRequired }
FilePickerModal.propTypes = { open: PropTypes.bool.isRequired, onClose: PropTypes.func.isRequired }
