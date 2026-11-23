import React, { useState } from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { InMemoryCache } from '@apollo/client'
import { MemoryRouter, Route, Routes, useParams } from 'react-router'
import { App, Button } from 'antd'

import UploadFile from 'graphql/UploadFile.graphql'
import FilePickerModal, { PICKER_FILES, pickerFiles } from './FilePickerModal'

const summary = (slicer, status = 'READY') => ({
  __typename: 'GcodeSummary',
  status,
  analysedAt: null,
  error: null,
  slicer,
  slicerVersion: null,
  printSeconds: null,
  filamentGrams: null,
  filamentMetres: null,
  footprint: null,
  toolCount: null,
  toolChanges: null,
  tools: [],
  filamentChanges: []
})
const file = (id, filename, { slicer = 'PrusaSlicer', status, createdAt = `2026-11-${10 + Number(id)}T10:00:00Z`, ...rest } = {}) => ({
  __typename: 'File',
  id,
  filename,
  filesize: 2400000,
  createdAt,
  isArchived: false,
  isDeleted: false,
  gcodeSummary: summary(slicer, status),
  ...rest
})
const FILES = [
  file('1', 'bracket_v3.gcode'),
  file('2', 'gear_housing.gcode', { slicer: 'Cura' }),
  file('3', 'benchy.gcode', { slicer: null }),
  file('4', 'old_part.gcode', { isArchived: true })
]

function AddPage () {
  const { fileId } = useParams()
  return <div>Add to Queue for file {fileId}</div>
}

// The queue page's button and the picker it opens
function Harness () {
  const [open, setOpen] = useState(false)
  return (
    <>
      <Button onClick={() => setOpen(true)}>Open Picker</Button>
      <span>{open ? 'Picking' : 'Not picking'}</span>
      <FilePickerModal open={open} onClose={() => setOpen(false)} />
    </>
  )
}

// `library.files`: what files(gcode: true) answers, each time it is asked
const renderPicker = (extraMocks = [], library = { files: FILES }) => render(
  <MockedProvider cache={new InMemoryCache()} mocks={[
    { request: { query: PICKER_FILES }, result: () => ({ data: { files: library.files } }), maxUsageCount: Number.POSITIVE_INFINITY },
    ...extraMocks
  ]}>
    <MemoryRouter initialEntries={['/queue']}>
      <App>
        <Routes>
          <Route path="/queue" element={<Harness />} />
          <Route path="/queue/add/:fileId" element={<AddPage />} />
        </Routes>
      </App>
    </MemoryRouter>
  </MockedProvider>
)

const open = async () => {
  await userEvent.click(screen.getByRole('button', { name: 'Open Picker' }))
  return within(await screen.findByRole('listbox', { name: 'G-code files' }))
}
const names = (list) => list.getAllByRole('option').map((option) => option.querySelector('[title]').title)

describe('pickerFiles', () => {
  it('leaves out archived and deleted files, puts the latest first and searches by name', () => {
    const files = [...FILES, file('5', 'gone.gcode', { isDeleted: true })]
    expect(pickerFiles(files).map((each) => each.id)).toEqual(['3', '2', '1'])
    expect(pickerFiles(files, ' GEAR ').map((each) => each.id)).toEqual(['2'])
  })
})

describe('FilePickerModal', () => {
  it('lists the G-code files with their slicer and size', async () => {
    renderPicker()
    const list = await open()

    expect(screen.getByRole('dialog', { name: 'Choose a file to add to the queue' })).toBeInTheDocument()
    expect(names(list)).toEqual(['benchy.gcode', 'gear_housing.gcode', 'bracket_v3.gcode'])
    expect(list.getByText(/^Cura · 2\.4/)).toBeInTheDocument()
    expect(list.getByText(/^Slicer not recognized · 2\.4/)).toBeInTheDocument()
    expect(screen.getByText('Only G-code files are listed. A model has to be sliced before it can be queued.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Continue' })).toBeDisabled()
  })

  it('searches the files by name', async () => {
    renderPicker()
    const list = await open()

    await userEvent.type(screen.getByRole('searchbox', { name: 'Search files' }), 'bra')
    expect(names(list)).toEqual(['bracket_v3.gcode'])
    await userEvent.type(screen.getByRole('searchbox', { name: 'Search files' }), 'zzz')
    expect(await screen.findByText('No G-code file matches')).toBeInTheDocument()
  })

  it('continues with the file chosen, to its Add to Queue page', async () => {
    renderPicker()
    const list = await open()

    await userEvent.click(list.getByText('gear_housing.gcode'))
    expect(list.getAllByRole('option')[1]).toHaveAttribute('aria-selected', 'true')
    await userEvent.click(screen.getByRole('button', { name: 'Continue with gear_housing.gcode' }))

    expect(await screen.findByText('Add to Queue for file 2')).toBeInTheDocument()
  })

  it('goes back to the queue', async () => {
    renderPicker()
    await open()

    expect(screen.getByText('Picking')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Back to Queue' }))
    expect(screen.getByText('Not picking')).toBeInTheDocument()
  })

  it('says so when there is no G-code file', async () => {
    renderPicker([], { files: [] })
    await userEvent.click(screen.getByRole('button', { name: 'Open Picker' }))

    expect(await screen.findByText('No G-code files yet')).toBeInTheDocument()
  })

  it('uploads a file and selects it', async () => {
    const uploaded = file('9', 'new_part.gcode', { createdAt: '2026-11-23T10:00:00Z' })
    const library = { files: FILES }
    renderPicker([
      {
        request: { query: UploadFile, variables: ({ input }) => input.fileAttributes.file.name === 'new_part.gcode' },
        result: () => {
          library.files = [...FILES, uploaded]
          return {
          data: {
            uploadFile: {
              __typename: 'UploadFilePayload',
              file: {
                __typename: 'File', id: '9', filename: 'new_part.gcode', filetype: '.gcode', filesize: 2400000, notes: '',
                createdAt: uploaded.createdAt, updatedAt: uploaded.createdAt, isArchived: false, isDeleted: false,
                archivedAt: null, downloadUrl: '/new_part.gcode', labels: { __typename: 'LabelConnection', edges: [] }
              }
            }
          }
          }
        }
      }
    ], library)
    await open()

    const input = document.querySelector('input[type="file"]')
    await userEvent.upload(input, new File(['G28'], 'new_part.gcode', { type: 'text/plain' }))

    expect(await screen.findByRole('button', { name: 'Continue with new_part.gcode' })).toBeEnabled()
  })
})
