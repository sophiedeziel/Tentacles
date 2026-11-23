import React, { useRef, useState } from 'react'

import { useQueueMutation } from '../useQueueActions'
import { CONFIRM_BED_CLEARED } from '../graphql/actions'
import BedClearedModal from './BedClearedModal'

// Bed Cleared, wherever a printer waits for its bed to be cleared (the queue page, the printer page):
//
//   const bedCleared = useBedCleared({ dispatchPaused, onDone: reload })
//   <Button onClick={() => bedCleared.ask(printer, fileName)}>Bed Cleared</Button>
//   {bedCleared.modal}
//
// `ask(printer, fileName)` opens the modal for `printer` ({ id, name, takesJobs }) and the print on its bed
// (`fileName`, optional); what it says is frozen when it opens. Bed Cleared sends confirmBedCleared(printerId); a
// refusal shows as a message. `onDone` runs after, either way (the page reloads).
export default function useBedCleared ({ dispatchPaused = false, onDone } = {}) {
  const run = useQueueMutation(onDone)
  const [asked, setAsked] = useState(null)
  const [open, setOpen] = useState(false)
  const [confirming, setConfirming] = useState(false)
  const busy = useRef(false)

  const ask = (printer, fileName) => {
    setAsked({ printer, fileName, dispatchPaused })
    setOpen(true)
  }
  const close = () => !busy.current && setOpen(false)
  const confirm = async () => {
    if (busy.current) return
    busy.current = true
    setConfirming(true)
    await run(CONFIRM_BED_CLEARED, { printerId: asked.printer.id }, 'confirmBedCleared', { failure: 'Bed Cleared failed' })
    busy.current = false
    setConfirming(false)
    setOpen(false)
  }

  const modal = (
    <BedClearedModal open={open} printer={asked?.printer} fileName={asked?.fileName}
      dispatchPaused={asked?.dispatchPaused} confirming={confirming} onConfirm={confirm} onCancel={close} />
  )

  return { ask, modal }
}
