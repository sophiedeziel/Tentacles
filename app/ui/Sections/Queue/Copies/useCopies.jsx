import React, { useState } from 'react'

import CopiesModal from './CopiesModal'

// Change Number of Copies and Print More Copies, from a row's "⋯" menu:
//
//   const copies = useCopies({ onSave: actions.setCopies })
//   copies.ask(job)   // job: { id, copies, copiesLeftToStart, file, prints }
//   {copies.modal}
//
// `onSave(job, total)` resolves to whether it was saved (useQueueActions shows a refusal): the dialog closes once
// saved, and stays open on a refusal.
export default function useCopies ({ onSave }) {
  const [job, setJob] = useState(null)
  const [saving, setSaving] = useState(false)

  const save = async (total) => {
    setSaving(true)
    const saved = await onSave(job, total)
    setSaving(false)
    if (saved) setJob(null)
  }

  // Keyed by the job: each opening starts from its own number of copies
  const modal = job && (
    <CopiesModal key={job.id} job={job} saving={saving} onSave={save} onCancel={() => !saving && setJob(null)} />
  )

  return { ask: setJob, modal }
}
