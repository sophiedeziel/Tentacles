import React, { useId, useState } from 'react'
import PropTypes from 'prop-types'
import { useQuery } from '@apollo/client/react'
import { InputNumber, Modal, Switch, Typography, theme } from 'antd'

import JobStatus from '../../../components/JobStatus/JobStatus'
import { COPIES_USE } from '../graphql/queue'
import { copiesDialog, copyCounts, copyUse, estimateRows } from './copiesText'
import * as classes from './CopiesModal.module.less'

const { Text } = Typography

const MAX_COPIES = 500

// "Now: ✓ Completed 2 · Printing 1 · Enqueued 7": where a batch's copies are
function NowLine ({ job }) {
  const { done, printing, waiting } = copyCounts(job)
  return (
    <div className={classes.now}>
      <Text type="secondary">Now:</Text>
      <JobStatus status="completed" /><span>{done}</span>
      <JobStatus status="active" /><span>{printing}</span>
      <JobStatus status="enqueued" /><span>{waiting}</span>
    </div>
  )
}

// The filament and time the change adds (Print More Copies) or leaves to print (Change Number of Copies), from what
// one copy uses (its file's G-code summary, asked when the dialog opens). Nothing until it is known.
function Estimate ({ rows }) {
  const { token } = theme.useToken()
  if (rows.length === 0) return null
  return (
    <dl className={classes.estimate} style={{ background: token.colorFillQuaternary, '--line': token.colorSplit }}>
      {rows.map((row) => (
        <div key={row.label} className={classes.estimateRow}>
          <dt><Text type="secondary">{row.label}</Text></dt>
          <dd>{row.value}</dd>
        </div>
      ))}
    </dl>
  )
}

// Print More Copies' "Keep all copies on the same printer": for the whole batch it becomes
function SamePrinter ({ checked, onChange }) {
  return (
    <div className={classes.samePrinter}>
      <div className={classes.samePrinterText}>
        <Text strong>Keep all copies on the same printer</Text>
        <Text type="secondary">
          Applies to the whole batch, including the copy already in the queue. Off: each copy goes to any selected
          printer that is ready.
        </Text>
      </div>
      <Switch checked={checked} onChange={onChange} aria-label="Keep all copies on the same printer" />
    </div>
  )
}

// The copies dialog (the ChangeCopies and MoreCopies frames): Total copies with − and +, never below the copies done
// and printing, what the change does, and why the floor is where it is, over what the copies use. A single print
// becomes a batch, and says whether its copies stay on the same printer. Controlled: `job` (null when closed),
// `saving`, `onSave(total, { samePrinter })` (samePrinter: null for a batch, unchanged), `onCancel`. useCopies runs it.
export default function CopiesModal ({ job, saving = false, onSave, onCancel }) {
  const id = useId()
  const [total, setTotal] = useState(() => (job ? Math.max(job.copies, job.copies === 1 ? 2 : 0) : 1))
  const [samePrinter, setSamePrinter] = useState(() => !!job?.samePrinter)
  const { data } = useQuery(COPIES_USE, { variables: { id: job?.id }, skip: !job })
  if (!job) return null

  const single = job.copies === 1
  const dialog = copiesDialog(job, total)
  const rows = data?.globalQueue?.printJob ? estimateRows(job, total, copyUse(data.globalQueue.printJob)) : []
  // An emptied field keeps the last number until another is typed
  const change = (value) => {
    if (value != null) setTotal(Math.max(dialog.min, Math.min(MAX_COPIES, Math.round(value))))
  }

  return (
    <Modal open title={dialog.title} okText={dialog.ok} cancelText={dialog.keep} confirmLoading={saving}
      okButtonProps={{ disabled: dialog.unchanged }} centered width={460} destroyOnHidden onCancel={onCancel}
      onOk={() => onSave(total, { samePrinter: single ? samePrinter : null })}>
      <div className={classes.body}>
        {!single && <NowLine job={job} />}
        <div className={classes.total}>
          <div className={classes.field}>
            <label htmlFor={id} className={classes.label}>Total copies</label>
            <InputNumber id={id} mode="spinner" min={dialog.min} max={MAX_COPIES} precision={0} value={total}
              onChange={change} style={{ width: 140 }} />
          </div>
          <span className={classes.change}>{dialog.change}</span>
        </div>
        {dialog.note && <Text type="secondary">{dialog.note}</Text>}
        <Estimate rows={rows} />
        {single && <SamePrinter checked={samePrinter} onChange={setSamePrinter} />}
      </div>
    </Modal>
  )
}

NowLine.propTypes = { job: PropTypes.object.isRequired }
Estimate.propTypes = {
  rows: PropTypes.arrayOf(PropTypes.shape({ label: PropTypes.string.isRequired, value: PropTypes.string.isRequired }))
    .isRequired
}
SamePrinter.propTypes = { checked: PropTypes.bool.isRequired, onChange: PropTypes.func.isRequired }
CopiesModal.propTypes = {
  job: PropTypes.shape({
    id: PropTypes.string.isRequired,
    copies: PropTypes.number.isRequired,
    copiesLeftToStart: PropTypes.number.isRequired,
    samePrinter: PropTypes.bool,
    file: PropTypes.object.isRequired,
    prints: PropTypes.arrayOf(PropTypes.object).isRequired
  }),
  saving: PropTypes.bool,
  onSave: PropTypes.func.isRequired,
  onCancel: PropTypes.func.isRequired
}
