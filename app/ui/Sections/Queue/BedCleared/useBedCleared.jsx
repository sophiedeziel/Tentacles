import React, { useRef, useState } from 'react'

import { useQueueMutation } from '../useQueueActions'
import { CONFIRM_BED_CLEARED } from '../graphql/actions'
import BedClearedModal from './BedClearedModal'

// Bed Cleared, wherever a printer waits for its bed to be cleared (the queue page, the printer page):
//
//   const bedCleared = useBedCleared({ dispatchPaused, onDone: reload })
//   <Button onClick={() => bedCleared.ask(printer)}>Bed Cleared</Button>
//   {bedCleared.modal}
//
// `ask(printer)` opens the modal for `printer` ({ id, name, takesJobs, takesNext, printOnBed }: takesNext, the job it
// takes next, is named as "Next for it"; printOnBed is the print on its bed the page shows). What it says and the print
// it clears are frozen when it opens: Bed Cleared sends confirmBedCleared(printerId, expectedPrintId: that print's id),
// so a modal left open never clears a newer print. A refusal (the bed now holds another print) shows the server's
// message. `onDone` runs after, either way (the page reloads).
export default function useBedCleared ({ dispatchPaused = false, onDone } = {}) {
  const run = useQueueMutation(onDone)
  const [asked, setAsked] = useState(null)
  const [open, setOpen] = useState(false)
  const [confirming, setConfirming] = useState(false)
  const busy = useRef(false)

  const ask = (printer) => {
    setAsked({ printer, dispatchPaused })
    setOpen(true)
  }
  const close = () => !busy.current && setOpen(false)
  const confirm = async () => {
    if (busy.current) return
    busy.current = true
    setConfirming(true)
    const { printer } = asked
    await run(CONFIRM_BED_CLEARED, { printerId: printer.id, expectedPrintId: printer.printOnBed.id }, 'confirmBedCleared',
      { failure: 'Bed Cleared failed' })
    busy.current = false
    setConfirming(false)
    setOpen(false)
  }

  const modal = (
    <BedClearedModal open={open} printer={asked?.printer}
      dispatchPaused={asked?.dispatchPaused} confirming={confirming} onConfirm={confirm} onCancel={close} />
  )

  return { ask, modal }
}
