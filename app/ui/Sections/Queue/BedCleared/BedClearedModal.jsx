import React from 'react'
import PropTypes from 'prop-types'
import { Modal, Typography } from 'antd'

// The copy a printer takes next of a print job: the first one not handed out yet
const nextCopy = (job) => job.copies - job.copiesLeftToStart + 1

// What the Bed Cleared modal says (the BedConfirm frame): whether the printer starts printing once its bed is clear
// and what it takes next (`takesNext`, the job the queue lines up for it, as if dispatch ran), then what to check.
// A printer not taking jobs won't start the next one, and nothing starts while dispatch is paused.
export function bedClearedText ({ printerName, takesJobs = true, dispatchPaused = false, takesNext = null }) {
  let body = 'It starts printing as soon as it can pick a job from the queue.'
  if (!takesJobs) body = `${printerName} isn't taking jobs from the queue, so it won't start the next one.`
  else if (dispatchPaused) {
    body = 'Dispatch is paused, so it will not start yet. It picks a job from the queue as soon as you resume dispatch.'
  } else if (takesNext) {
    const copy = takesNext.copies > 1 ? `, copy ${nextCopy(takesNext)} of ${takesNext.copies}` : ''
    body = `${body} Next for it: ${takesNext.file.filename}${copy}.`
  }

  return {
    title: `Is the bed of ${printerName} clear?`,
    body,
    check: 'Check that the part and any leftover filament are off the bed first.'
  }
}

// Bed Cleared (the BedConfirm frame): asks whether the bed is clear, says what the printer does then, and confirms.
// Controlled: `open`, `confirming` while the mutation runs, `onConfirm`, `onCancel`. `printer` needs
// { name, takesJobs, takesNext }. useBedCleared runs it.
export default function BedClearedModal ({ open, printer, dispatchPaused, confirming, onConfirm, onCancel }) {
  const text = printer && bedClearedText({
    printerName: printer.name, takesJobs: printer.takesJobs ?? true, dispatchPaused, takesNext: printer.takesNext
  })

  return (
    <Modal open={open} title={text?.title} okText="Bed Is Clear" cancelText="Not Yet" confirmLoading={confirming}
      onOk={onConfirm} onCancel={onCancel} centered width={440} destroyOnHidden>
      {text && (
        <>
          <Typography.Paragraph style={{ marginBottom: 8 }}>{text.body}</Typography.Paragraph>
          <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>{text.check}</Typography.Paragraph>
        </>
      )}
    </Modal>
  )
}

BedClearedModal.propTypes = {
  open: PropTypes.bool.isRequired,
  printer: PropTypes.shape({
    name: PropTypes.string.isRequired,
    takesJobs: PropTypes.bool,
    takesNext: PropTypes.shape({
      copies: PropTypes.number.isRequired,
      copiesLeftToStart: PropTypes.number.isRequired,
      file: PropTypes.shape({ filename: PropTypes.string.isRequired }).isRequired
    })
  }),
  dispatchPaused: PropTypes.bool,
  confirming: PropTypes.bool,
  onConfirm: PropTypes.func.isRequired,
  onCancel: PropTypes.func.isRequired
}
