import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { MemoryRouter } from 'react-router'

import FilesList from './FilesList'
import Files from 'graphql/Files.graphql'
import UploadFile from 'graphql/UploadFile.graphql'

const file = (id, filename, { isArchived = false } = {}) => ({
  __typename: 'File',
  id,
  filename,
  filetype: '.gcode',
  filesize: 1200,
  notes: null,
  createdAt: '2026-11-15T10:00:00Z',
  updatedAt: '2026-11-15T10:00:00Z',
  isArchived,
  isDeleted: false,
  archivedAt: null,
  downloadUrl: `/files/${id}/download`,
  labels: { __typename: 'LabelConnection', edges: [] }
})

const library = (files) => ({
  request: { query: Files },
  result: { data: { files, labels: { __typename: 'LabelConnection', edges: [] } } }
})

const renderPage = (mocks) => render(
  <MockedProvider mocks={mocks}>
    <MemoryRouter initialEntries={['/files']}><FilesList /></MemoryRouter>
  </MockedProvider>
)

describe('FilesList', () => {
  it('invites to upload files when the library is empty, without the empty table or the drop zone', async () => {
    renderPage([library([])])

    expect(await screen.findByText('No files yet')).toBeInTheDocument()
    expect(screen.getByText('Upload G-code or STL files to print them on any printer.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /Upload files/ })).toBeInTheDocument()
    expect(screen.queryByRole('table')).not.toBeInTheDocument()
    expect(screen.queryByText('Click or drag file to this area to upload')).not.toBeInTheDocument()
  })

  it('uploads from the empty library, then lists the file', async () => {
    const uploaded = file('7', 'benchy.gcode')
    renderPage([
      library([]),
      {
        request: { query: UploadFile, variables: ({ input }) => input.fileAttributes.file.name === 'benchy.gcode' },
        result: { data: { uploadFile: { __typename: 'UploadFilePayload', file: uploaded } } }
      }
    ])
    await screen.findByText('No files yet')

    const input = screen.getByRole('button', { name: /Upload files/ }).closest('.ant-upload').querySelector('input')
    await userEvent.upload(input, new File(['G28'], 'benchy.gcode'))

    expect(await screen.findByRole('link', { name: 'benchy.gcode' })).toBeInTheDocument()
    expect(screen.queryByText('No files yet')).not.toBeInTheDocument()
  })

  it('lists the files in a table, with the drop zone under it', async () => {
    renderPage([library([file('1', 'benchy.gcode'), file('2', 'old.gcode', { isArchived: true })])])

    const table = await screen.findByRole('table')
    expect(within(table).getByRole('link', { name: 'benchy.gcode' })).toBeInTheDocument()
    expect(within(table).queryByText('old.gcode')).not.toBeInTheDocument()
    expect(screen.getByText('Click or drag file to this area to upload')).toBeInTheDocument()
    expect(screen.queryByText('No files yet')).not.toBeInTheDocument()
  })

  it('says when nothing is archived, from the empty library too', async () => {
    renderPage([library([])])

    await userEvent.click(await screen.findByRole('tab', { name: 'Archived' }))

    expect(screen.getByText('No archived files')).toBeInTheDocument()
    expect(screen.getByRole('tab', { name: 'Archived' })).toHaveAttribute('aria-selected', 'true')
    expect(screen.queryByText('No files yet')).not.toBeInTheDocument()
  })
})
