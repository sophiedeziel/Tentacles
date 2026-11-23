import React from 'react'
import { describe, expect, it } from 'vitest'
import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MockedProvider } from '@apollo/client/testing/react'
import { MemoryRouter } from 'react-router'

import FilesList from './FilesList'
import Files from 'graphql/Files.graphql'
import UploadFile from 'graphql/UploadFile.graphql'
import { GLOBAL_QUEUE_ENABLED } from '../../Queue/graphql/queue'

const file = (id, filename, { isArchived = false, filetype = '.gcode' } = {}) => ({
  __typename: 'File',
  id,
  filename,
  filetype,
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

// globalQueue is null while the global queue's flag is off
const flag = (on) => ({
  request: { query: GLOBAL_QUEUE_ENABLED },
  result: { data: { globalQueue: on ? { __typename: 'GlobalQueue', dispatchPaused: false } : null } }
})

const renderPage = (mocks, { queue = false } = {}) => render(
  <MockedProvider mocks={[flag(queue), ...mocks]}>
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

  describe('the row action', () => {
    const files = [file('1', 'benchy.gcode'), file('2', 'benchy.stl', { filetype: '.stl' })]
    const action = async (filename) => {
      const table = await screen.findByRole('table')
      return within(table).getByRole('link', { name: filename }).closest('tr')
    }

    it('adds a G-code file to the queue while it is on', async () => {
      renderPage([library(files)], { queue: true })

      const row = await action('benchy.gcode')
      const link = await within(row).findByRole('link', { name: /Add to Queue/ })
      expect(link).toHaveAttribute('href', '/queue/add/1')
    })

    it('opens any other file, since the queue prints G-code only', async () => {
      renderPage([library(files)], { queue: true })

      const row = await action('benchy.stl')
      expect(within(row).getByRole('link', { name: 'Edit' })).toHaveAttribute('href', '/files/2')
      expect(within(row).queryByRole('link', { name: /Add to Queue/ })).not.toBeInTheDocument()
    })

    it('has no Add to Queue while the queue is off, and no print page', async () => {
      renderPage([library(files)])

      const row = await action('benchy.gcode')
      expect(within(row).getByRole('link', { name: 'Edit' })).toHaveAttribute('href', '/files/1')
      expect(screen.queryByRole('link', { name: /Add to Queue/ })).not.toBeInTheDocument()
      expect(screen.queryByRole('link', { name: /Print/ })).not.toBeInTheDocument()
    })
  })
})
