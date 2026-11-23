import React, { useId, useState } from 'react'
import PropTypes from 'prop-types'
import { InputNumber, Modal, Typography } from 'antd'

import JobStatus from '../../../components/JobStatus/JobStatus'
import { copiesDialog, copyCounts } from './copiesText'
import * as classes from './CopiesModal.module.less'

const MAX_COPIES = 500

// "Now: ✓ Completed 2 · Printing 1 · Enqueued 7": where a batch's copies are
function NowLine ({ job }) {
  const { done, printing, waiting } = copyCounts(job)
  return (
    <div className={classes.now}>
      <Typography.Text type="secondary">Now:</Typography.Text>
      <JobStatus status="completed" /><span>{done}</span>
      <JobStatus status="active" /><span>{printing}</span>
      <JobStatus status="enqueued" /><span>{waiting}</span>
    </div>
  )
}

// The copies dialog (the ChangeCopies and MoreCopies frames, without their estimates): Total copies with − and +,
// never below the copies done and printing, what the change does, and why the floor is where it is. A single print
// becomes a batch. Controlled: `job` (null when closed), `saving`, `onSave(total)`, `onCancel`. useCopies runs it.
export default function CopiesModal ({ job, saving = false, onSave, onCancel }) {
  const id = useId()
  const [total, setTotal] = useState(() => (job ? Math.max(job.copies, job.copies === 1 ? 2 : 0) : 1))
  if (!job) return null

  const dialog = copiesDialog(job, total)
  // An emptied field keeps the last number until another is typed
  const change = (value) => {
    if (value != null) setTotal(Math.max(dialog.min, Math.min(MAX_COPIES, Math.round(value))))
  }

  return (
    <Modal open title={dialog.title} okText={dialog.ok} cancelText={dialog.keep} confirmLoading={saving}
      okButtonProps={{ disabled: dialog.unchanged }} onOk={() => onSave(total)} onCancel={onCancel} centered
      width={460} destroyOnHidden>
      <div className={classes.body}>
        {job.copies > 1 && <NowLine job={job} />}
        <div className={classes.total}>
          <div className={classes.field}>
            <label htmlFor={id} className={classes.label}>Total copies</label>
            <InputNumber id={id} mode="spinner" min={dialog.min} max={MAX_COPIES} precision={0} value={total}
              onChange={change} style={{ width: 140 }} />
          </div>
          <span className={classes.change}>{dialog.change}</span>
        </div>
        {dialog.note && <Typography.Text type="secondary">{dialog.note}</Typography.Text>}
      </div>
    </Modal>
  )
}

NowLine.propTypes = { job: PropTypes.object.isRequired }
CopiesModal.propTypes = {
  job: PropTypes.shape({
    id: PropTypes.string.isRequired,
    copies: PropTypes.number.isRequired,
    copiesLeftToStart: PropTypes.number.isRequired,
    file: PropTypes.object.isRequired,
    prints: PropTypes.arrayOf(PropTypes.object).isRequired
  }),
  saving: PropTypes.bool,
  onSave: PropTypes.func.isRequired,
  onCancel: PropTypes.func.isRequired
}
