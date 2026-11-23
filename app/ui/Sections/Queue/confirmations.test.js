import { describe, expect, it } from 'vitest'

import { cancelConfirmation, removeConfirmation } from './confirmations'
import { BATCH, MK4, print, waitingJob } from './fixtures'

describe('removeConfirmation', () => {
  it('names the file and the copy waiting', () => {
    expect(removeConfirmation(waitingJob())).toEqual({
      title: 'Remove phone_stand.gcode from the queue?',
      body: 'The copy waiting to start is removed. The file stays in your library.',
      ok: 'Remove from Queue',
      keep: 'Keep in Queue'
    })
  })

  it('counts the copies waiting, and says the ones printing finish', () => {
    const job = { ...BATCH, copiesLeftToStart: 4, prints: [...BATCH.prints, { ...BATCH.prints[1], id: '33', status: 'ENQUEUED' }] }
    expect(removeConfirmation(job).body)
      .toBe('The 4 copies waiting to start are removed. The 2 copies printing now finish. The file stays in your library.')
  })
})

describe('cancelConfirmation', () => {
  it('words it as the dashboard does, with the file on the row and the printer’s progress', () => {
    const copy = print({ id: '32', printer: MK4, jobId: '12', copies: 3, jobFile: BATCH.file, progress: 40 })
    expect(cancelConfirmation(copy)).toMatchObject({
      title: 'Cancel this print?',
      ok: 'Cancel Print',
      keep: 'Keep Printing',
      body: 'cable_clip.gcode stops at 64% and can’t be resumed. The file stays in your library.'
    })
  })
})
