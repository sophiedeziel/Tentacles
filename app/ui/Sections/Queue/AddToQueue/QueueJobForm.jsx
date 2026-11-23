import React, { useEffect, useMemo, useRef, useState } from 'react'
import PropTypes from 'prop-types'
import { useQuery } from '@apollo/client/react'
import { Button, theme } from 'antd'

import { PRINTER_FITS, QUEUE_ESTIMATE } from './graphql/addToQueue'
import {
  clearAll, fillEmpty, gcodeFilament, jobVariables, savedColour, selectAll, selectedPrinterIds, tick
} from './formRules'
import { FileCard, FilamentCard, OrderCard, PrintersCard } from './sections'
import SummaryCard from './SummaryCard'
import * as classes from './AddToQueue.module.less'

export const NEW_JOB = {
  copies: 1,
  // Empty until the G-code fills them (see fillEmpty)
  material: null,
  colour: null,
  samePrinter: false,
  position: 'BOTTOM',
  held: false,
  // The automatic selection: every printer that can print it (saved as all_capable)
  selection: { touched: false, ticked: [] }
}

// The options of a job in the queue, the Add to Queue form's cards beside its Summary: File and Copies, Filament,
// Printers, Order and Timing. The Summary (queueEstimate) and the Printers (printerFits) follow the form as it changes.
//
// - file: the file, with its gcodeSummary (the page refetches a PENDING one: the empty fields take what it says)
// - materials, colours: what the Material and Colour fields offer
// - initial: the options to start from (NEW_JOB for a new job)
// - printJobId: the job edited, if any (its estimate counts only its copies still waiting)
// - submitLabel(copies), cancelLabel: the Summary's buttons
// - onSubmit(variables): saves (addToQueue's options but the file; printerIds null for the automatic selection),
//   resolving to whether it was saved. onCancel: leaves.
export default function QueueJobForm ({
  file, materials, colours, initial = NEW_JOB, printJobId = null, submitLabel, cancelLabel = 'Cancel', onSubmit, onCancel
}) {
  const { token } = theme.useToken()
  const [copies, setCopies] = useState(initial.copies)
  const [fields, setFields] = useState({ material: initial.material, colour: initial.colour })
  const [samePrinter, setSamePrinter] = useState(initial.samePrinter)
  const [position, setPosition] = useState(initial.position)
  const [held, setHeld] = useState(initial.held)
  const [selection, setSelection] = useState(initial.selection)
  const [saving, setSaving] = useState(false)

  const gcode = useMemo(() => gcodeFilament(file.gcodeSummary), [file.gcodeSummary])
  // Once the G-code is read, its values fill the fields still empty, and nothing else
  useEffect(() => { setFields((current) => fillEmpty(current, gcode)) }, [gcode])

  const material = fields.material || null
  const colour = savedColour(fields.colour)
  const fitsQuery = useQuery(PRINTER_FITS, { variables: { fileId: file.id, material, colour } })
  const fits = (fitsQuery.data ?? fitsQuery.previousData)?.printerFits ?? null
  const selected = useMemo(() => (fits ? selectedPrinterIds(fits, selection) : []), [fits, selection])

  const variables = jobVariables({ copies, material, colour, samePrinter, position, held }, { fits: fits ?? [], selection })
  const estimateQuery = useQuery(QUEUE_ESTIMATE, { variables: { fileId: file.id, printJobId, ...variables } })
  const estimate = (estimateQuery.data ?? estimateQuery.previousData)?.queueEstimate ?? null

  // A summary read since the page opened changes the fits and the totals even when the fields don't
  const { refetch: refetchFits } = fitsQuery
  const { refetch: refetchEstimate } = estimateQuery
  const status = useRef(gcode.status)
  useEffect(() => {
    const was = status.current
    status.current = gcode.status
    if (was === gcode.status || gcode.status !== 'READY') return
    refetchFits()
    refetchEstimate()
  }, [gcode.status, refetchFits, refetchEstimate])

  const selectedFits = (fits ?? []).filter((fit) => selected.includes(fit.printer.id))
  const job = {
    copies: estimate?.copiesToPrint ?? copies,
    copiesLeftToStart: estimate?.copiesToPrint ?? copies,
    samePrinter,
    prints: [],
    eligiblePrinters: selectedFits.map((fit) => fit.printer),
    needs: { known: gcode.status === 'READY', filaments: [{ tool: 0, material, colour }] }
  }
  const noPrinter = selection.touched && selected.length === 0

  const submit = async () => {
    setSaving(true)
    const saved = await onSubmit(variables)
    if (!saved) setSaving(false)
  }

  return (
    <div className={classes.layout} style={{ '--line': token.colorSplit }}>
      <div className={classes.cards}>
        <FileCard file={file} copies={copies} onCopies={setCopies} />
        <FilamentCard fields={fields} gcode={gcode} materials={materials} colours={colours}
          footprint={gcode.status === 'READY' ? file.gcodeSummary.footprint : null} onChange={setFields} />
        <PrintersCard fits={fits} loading={fitsQuery.loading} selected={selected}
          onTick={(id, checked) => setSelection(tick(fits, selection, id, checked))}
          onSelectAll={() => setSelection(selectAll(fits))} onClear={() => setSelection(clearAll())}
          samePrinter={samePrinter} onSamePrinter={setSamePrinter} />
        <OrderCard position={position} onPosition={setPosition} held={held} onHeld={setHeld} />
      </div>
      <SummaryCard estimate={estimate} job={job}
        readyPrinters={selectedFits.filter((fit) => fit.result === 'READY').length}>
        <Button type="primary" block onClick={submit} loading={saving} disabled={noPrinter}
          title={noPrinter ? 'Choose at least one printer' : undefined}>
          {submitLabel(copies)}
        </Button>
        <Button block onClick={onCancel}>{cancelLabel}</Button>
      </SummaryCard>
    </div>
  )
}

QueueJobForm.propTypes = {
  file: PropTypes.shape({
    id: PropTypes.string.isRequired,
    filename: PropTypes.string.isRequired,
    filesize: PropTypes.number.isRequired,
    notes: PropTypes.string,
    gcodeSummary: PropTypes.object
  }).isRequired,
  materials: PropTypes.arrayOf(PropTypes.string).isRequired,
  colours: PropTypes.arrayOf(PropTypes.string).isRequired,
  initial: PropTypes.shape({
    copies: PropTypes.number.isRequired,
    material: PropTypes.string,
    colour: PropTypes.string,
    samePrinter: PropTypes.bool.isRequired,
    position: PropTypes.oneOf(['TOP', 'BOTTOM']).isRequired,
    held: PropTypes.bool.isRequired,
    selection: PropTypes.shape({ touched: PropTypes.bool.isRequired, ticked: PropTypes.arrayOf(PropTypes.string) })
      .isRequired
  }),
  printJobId: PropTypes.string,
  submitLabel: PropTypes.func.isRequired,
  cancelLabel: PropTypes.string,
  onSubmit: PropTypes.func.isRequired,
  onCancel: PropTypes.func.isRequired
}
