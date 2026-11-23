import React, { useEffect, useState } from 'react'
import PropTypes from 'prop-types'
import { useMutation, useQuery } from '@apollo/client/react'
import { Alert, App, Button, Descriptions, Skeleton, Tooltip, Typography } from 'antd'

import { formatPrintTime } from '../../../../../utils/time'
import { GCODE_SUMMARY, REANALYSE_GCODE } from './graphql/gcodeSummary'
import * as classes from './GcodeSummary.module.less'

const { Text } = Typography

export const POLL_INTERVAL = 3000

// An unknown value: never a dash, a zero or a blank
const NotKnown = () => <Text type="secondary">Not known</Text>

const grams = (value) => `${value.toFixed(1)} g`
const metres = (value) => `${value.toFixed(2)} m`
// Millimetres: whole when the tenth is zero, else to the tenth
const mm = (value) => {
  const rounded = Math.round(value * 10) / 10
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1)
}
// "#FF8800" or "FF8800", as the slicer wrote it; anything else is no colour
const swatchColour = (hex) => (/^#?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(hex ?? '') ? `#${hex.replace('#', '')}` : null)
const plural = (count, word) => `${count} ${word}${count === 1 ? '' : 's'}`

// Two values on one line, "12.4 g · 4.05 m", each Not known on its own; one Not known when neither is known
function Pair ({ first, second }) {
  if (first == null && second == null) return <NotKnown />
  return <>{first ?? <NotKnown />} · {second ?? <NotKnown />}</>
}

Pair.propTypes = { first: PropTypes.node, second: PropTypes.node }

function Material ({ tool }) {
  if (tool.material) return tool.material
  if (tool.materialRaw) {
    return (
      <Tooltip title="Not a material the queue can match">
        <Text type="secondary" tabIndex={0} className={classes.raw}>{tool.materialRaw}</Text>
      </Tooltip>
    )
  }
  return <NotKnown />
}

function Tool ({ tool, labelled }) {
  const colour = swatchColour(tool.colourHex)
  return (
    <div className={classes.line}>
      {labelled && <span className={classes.toolLabel}>T{tool.tool}</span>}
      {colour
        ? <span className={classes.swatch} style={{ background: colour }} role="img" aria-label={`Colour ${colour}`} />
        : <><Text type="secondary">Colour not known</Text> ·</>}
      <span><Material tool={tool} /> · <Pair first={tool.grams != null ? grams(tool.grams) : null}
        second={tool.metres != null ? metres(tool.metres) : null} /></span>
    </div>
  )
}

function Filament ({ summary }) {
  const { tools } = summary
  return (
    <>
      <Pair first={summary.filamentGrams != null ? grams(summary.filamentGrams) : null}
        second={summary.filamentMetres != null ? metres(summary.filamentMetres) : null} />
      {tools.map((tool) => <Tool key={tool.tool} tool={tool} labelled={tools.length > 1} />)}
    </>
  )
}

function Footprint ({ footprint }) {
  if (!footprint) return <NotKnown />
  return (
    <>
      <div>{mm(footprint.width)} × {mm(footprint.depth)} mm</div>
      <div>Height {footprint.height != null ? `${mm(footprint.height)} mm` : <NotKnown />}</div>
    </>
  )
}

// "Layer 27 (Z 5.4 mm)", "Z 5.4 mm" or "Line 1234", each one jumping to its line in the editor
const changeLabel = ({ line, z, layer }) => {
  if (layer != null && z != null) return `Layer ${layer} (Z ${mm(z)} mm)`
  if (layer != null) return `Layer ${layer}`
  if (z != null) return `Z ${mm(z)} mm`
  return `Line ${line}`
}

function FilamentChanges ({ changes, onLineSelect }) {
  if (changes.length === 0) return 'None'
  return changes.map((change) => (
    <div key={change.line}>
      <Button type="link" size="small" className={classes.jump} onClick={() => onLineSelect(change.line)}>
        {changeLabel(change)}
      </Button>
    </div>
  ))
}

function Slicer ({ slicer, version }) {
  if (!slicer) return <NotKnown />
  if (!version) return <>{slicer} <Text type="secondary">(version not known)</Text></>
  return `${slicer} ${version}`
}

function Ready ({ summary, onLineSelect }) {
  const items = [
    {
      key: 'time',
      label: 'Print time',
      children: summary.printSeconds != null ? formatPrintTime(summary.printSeconds) : <NotKnown />
    },
    { key: 'filament', label: 'Filament', children: <Filament summary={summary} /> },
    { key: 'footprint', label: 'Footprint', children: <Footprint footprint={summary.footprint} /> },
    {
      key: 'tools',
      label: 'Tools',
      children: <Pair first={summary.toolCount != null ? `${summary.toolCount} used` : null}
        second={summary.toolChanges != null ? plural(summary.toolChanges, 'change') : null} />
    },
    {
      key: 'changes',
      label: 'Filament changes',
      children: <FilamentChanges changes={summary.filamentChanges} onLineSelect={onLineSelect} />
    },
    { key: 'slicer', label: 'Slicer', children: <Slicer slicer={summary.slicer} version={summary.slicerVersion} /> }
  ]
  return <Descriptions size="small" bordered column={1} items={items} className={classes.details} />
}

function Failed ({ fileId, error }) {
  const { message } = App.useApp()
  const [reanalyse] = useMutation(REANALYSE_GCODE)
  const [busy, setBusy] = useState(false)

  // The returned file's summary is PENDING, which puts the component back to polling
  const run = async () => {
    setBusy(true)
    try {
      const { data } = await reanalyse({ variables: { input: { fileId } } })
      data.reanalyseGcode.errors.forEach(({ message: text }) => message.error(text))
    } catch (failure) {
      message.error(`Could not re-analyse the file: ${failure.message}`)
    }
    setBusy(false)
  }

  return (
    <Alert type="warning" showIcon className={classes.details}
      title="Couldn't read this file's print details."
      description={error}
      action={<Button size="small" onClick={run} loading={busy}>Re-analyse</Button>} />
  )
}

// The print details the server read from one file's G-code: time, filament, footprint, tools, filament changes and
// slicer. Self-contained (its own query by file id), so it can sit anywhere a file is shown. Nothing for a file that
// isn't G-code; while the server reads the file, it asks again every 3 s until the summary is ready or failed.
export default function GcodeSummary ({ fileId, onLineSelect }) {
  const { data, error, startPolling, stopPolling } = useQuery(GCODE_SUMMARY, {
    variables: { fileId },
    fetchPolicy: 'cache-and-network'
  })
  const summary = data?.file?.gcodeSummary ?? null
  const pending = summary?.status === 'PENDING'

  useEffect(() => {
    if (!pending) return undefined
    startPolling(POLL_INTERVAL)
    return () => stopPolling()
  }, [pending, startPolling, stopPolling])

  if (!data) {
    if (error) {
      return (
        <Alert type="error" showIcon className={classes.details}
          title="Could not load the print details" description={error.message} />
      )
    }
    return <Skeleton active title={false} paragraph={{ rows: 3 }} className={classes.details} />
  }
  if (!summary) return null

  if (summary.status === 'FAILED') return <Failed fileId={fileId} error={summary.error} />
  if (pending) {
    return (
      <div className={classes.details} role="status">
        <Text type="secondary">Analysing…</Text>
        <Skeleton active title={false} paragraph={{ rows: 4 }} />
      </div>
    )
  }
  return <Ready summary={summary} onLineSelect={onLineSelect} />
}

const toolShape = PropTypes.shape({
  tool: PropTypes.number.isRequired,
  material: PropTypes.string,
  materialRaw: PropTypes.string,
  colourHex: PropTypes.string,
  grams: PropTypes.number,
  metres: PropTypes.number
})
const changeShape = PropTypes.shape({ line: PropTypes.number.isRequired, z: PropTypes.number, layer: PropTypes.number })
const footprintShape = PropTypes.shape({
  width: PropTypes.number.isRequired, depth: PropTypes.number.isRequired, height: PropTypes.number
})
const summaryShape = PropTypes.shape({
  slicer: PropTypes.string,
  slicerVersion: PropTypes.string,
  printSeconds: PropTypes.number,
  filamentGrams: PropTypes.number,
  filamentMetres: PropTypes.number,
  footprint: footprintShape,
  toolCount: PropTypes.number,
  toolChanges: PropTypes.number,
  tools: PropTypes.arrayOf(toolShape).isRequired,
  filamentChanges: PropTypes.arrayOf(changeShape).isRequired
})

Material.propTypes = { tool: toolShape.isRequired }
Tool.propTypes = { tool: toolShape.isRequired, labelled: PropTypes.bool }
Filament.propTypes = { summary: summaryShape.isRequired }
Footprint.propTypes = { footprint: footprintShape }
FilamentChanges.propTypes = { changes: PropTypes.arrayOf(changeShape).isRequired, onLineSelect: PropTypes.func.isRequired }
Slicer.propTypes = { slicer: PropTypes.string, version: PropTypes.string }
Ready.propTypes = { summary: summaryShape.isRequired, onLineSelect: PropTypes.func.isRequired }
Failed.propTypes = { fileId: PropTypes.string.isRequired, error: PropTypes.string }

GcodeSummary.propTypes = {
  fileId: PropTypes.string.isRequired,
  onLineSelect: PropTypes.func.isRequired
}
