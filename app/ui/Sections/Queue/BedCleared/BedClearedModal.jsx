import React from 'react'
import PropTypes from 'prop-types'
import { Modal, Typography } from 'antd'

// What the Bed Cleared modal says: what to check (the print, named when known, and any leftover filament off the
// bed), then what happens next for the printer. A printer not taking jobs won't start the next one, and nothing
// starts while dispatch is paused; otherwise it can take the next job.
export function bedClearedText ({ printerName, fileName, takesJobs = true, dispatchPaused = false }) {
  const print = fileName || 'the last print'
  let next = `${printerName} can then take the next job in the queue.`
  if (!takesJobs) next = `${printerName} isn't taking jobs, so it won't start the next one.`
  else if (dispatchPaused) next = `Dispatch is paused, so ${printerName} won't start the next job until it resumes.`

  return {
    title: `Bed cleared on ${printerName}?`,
    check: `Check that ${print} and any leftover filament are off the bed.`,
    next
  }
}

// Bed Cleared (the BedConfirm frame): asks the person to check the bed, says what the printer does next, and
// confirms. Controlled: `open`, `confirming` while the mutation runs, `onConfirm`, `onCancel`. `printer` needs
// { name, takesJobs }; `fileName` is the print on the bed, when known. useBedCleared runs it.
export default function BedClearedModal ({ open, printer, fileName, dispatchPaused, confirming, onConfirm, onCancel }) {
  const text = printer && bedClearedText({ printerName: printer.name, fileName, takesJobs: printer.takesJobs, dispatchPaused })

  return (
    <Modal open={open} title={text?.title} okText="Bed Cleared" cancelText="Not Yet" confirmLoading={confirming}
      onOk={onConfirm} onCancel={onCancel} centered width={420} destroyOnHidden>
      {text && (
        <>
          <Typography.Paragraph>{text.check}</Typography.Paragraph>
          <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>{text.next}</Typography.Paragraph>
        </>
      )}
    </Modal>
  )
}

BedClearedModal.propTypes = {
  open: PropTypes.bool.isRequired,
  printer: PropTypes.shape({ name: PropTypes.string.isRequired, takesJobs: PropTypes.bool }),
  fileName: PropTypes.string,
  dispatchPaused: PropTypes.bool,
  confirming: PropTypes.bool,
  onConfirm: PropTypes.func.isRequired,
  onCancel: PropTypes.func.isRequired
}
