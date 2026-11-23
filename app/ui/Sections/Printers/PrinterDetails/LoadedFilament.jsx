import React, { useId, useState } from 'react'
import PropTypes from 'prop-types'
import { useMutation, useQuery, useSubscription } from '@apollo/client/react'
import { Alert, App, AutoComplete, Button, Card, Form, Select } from 'antd'

import { FilamentOutlined } from '../../../components/icons'
import { formatAgo } from '../../../utils/time'
import useNow from '../../../utils/useNow'
import filamentHint from './filamentHint'
import {
  CLEAR_LOADED_FILAMENT, LOADED_FILAMENT, LOADED_FILAMENT_CHANGED, SET_LOADED_FILAMENT
} from './graphql/loadedFilament'
import * as classes from './PrinterDetails.module.less'

const NOT_SET = { material: null, colour: '' }

// The list's materials, the ones the printer's specs name first (matched upper-cased, as the server stores them)
export function materialOptions (materials, printerMaterials = []) {
  const own = new Set(printerMaterials.map((material) => material.trim().toUpperCase()))
  const first = materials.filter((material) => own.has(material))
  const rest = materials.filter((material) => !own.has(material))
  return [...first, ...rest].map((material) => ({ value: material, label: material }))
}

const sameFilament = (a, b) => a.material === b.material && a.colour === b.colour

// The suggestions that hold what is typed, whatever its case
const filterColour = (typed, option) => option.value.toLowerCase().includes(typed.trim().toLowerCase())

// Implicit submission: Enter in a field submits the <form> around it, and the printer page's form is around this card
const keepEnter = (event) => {
  if (event.key === 'Enter') event.preventDefault()
}

// The filament loaded in one slot of a printer, saved on its own with Update Filament: live state, not one of the
// page's specs. It reads and writes nothing of the page's form: its own form context (no <form> of its own, since
// it may sit inside the page's) over local state, so its fields never make the page dirty, and Enter in them submits
// nothing. A change made elsewhere (pushed by printerStatusChanged) replaces the values unless they were edited
// here, which then keep the person's edits and say what it changed to.
//
// `demand` (the printer page's queue query, while the global queue is on): how many waiting jobs ask for each loaded
// filament, shown under the fields. Only for the filament it was counted for: a count for another (changed since)
// never shows.
export default function LoadedFilament ({ printerId, slot = 1, demand }) {
  const { message } = App.useApp()
  const id = useId()
  const now = useNow()
  const { data, error } = useQuery(LOADED_FILAMENT, { variables: { printerId }, fetchPolicy: 'cache-and-network' })
  useSubscription(LOADED_FILAMENT_CHANGED)
  const [setLoadedFilament] = useMutation(SET_LOADED_FILAMENT)
  const [clearLoadedFilament] = useMutation(CLEAR_LOADED_FILAMENT)
  // The values typed or picked here, and the saved filament they started from; null when untouched
  const [edit, setEdit] = useState(null)
  const [errors, setErrors] = useState({})
  const [busy, setBusy] = useState(null) // 'update' or 'remove'

  const loaded = data?.printer?.loadedFilaments.find((filament) => filament.slot === slot) ?? null
  const saved = loaded ? { material: loaded.material, colour: loaded.colour } : NOT_SET
  const values = edit ? edit.values : saved
  const complete = Boolean(values.material && values.colour.trim())
  const changedElsewhere = edit && !busy && !sameFilament(edit.from, saved)
  const asking = loaded && demand?.find((entry) => entry.slot === loaded.slot && sameFilament(entry, loaded))
  const hint = asking ? filamentHint(loaded, asking.waitingJobsAskingCount) : null

  // Back to the saved values: untouched again
  const change = (field, value) => {
    const next = { ...values, [field]: value ?? NOT_SET[field] }
    setEdit(sameFilament(next, saved) ? null : { values: next, from: edit ? edit.from : saved })
    setErrors(({ [field]: _changed, ...rest }) => rest)
  }

  // Under the field it concerns, the others (slot, printer not found) as messages; the values stay
  const refuse = (refused) => {
    const byField = {}
    refused.forEach(({ field, message: text }) => {
      if (field === 'material' || field === 'colour') byField[field] ??= text
      else message.error(text)
    })
    setErrors(byField)
  }

  const run = async (action, mutate, done) => {
    setBusy(action)
    setErrors({})
    try {
      const refused = await mutate()
      if (refused.length > 0) refuse(refused)
      else {
        setEdit(null)
        message.success(done)
      }
    } catch (failure) {
      message.error(`Could not ${action} the filament: ${failure.message}`)
    }
    setBusy(null)
  }

  const update = () => run('update', async () => {
    const input = { printerId, slot, material: values.material, colour: values.colour }
    const { data: result } = await setLoadedFilament({ variables: { input } })
    return result.setLoadedFilament.errors
  }, 'Filament updated')

  const remove = () => run('remove', async () => {
    const { data: result } = await clearLoadedFilament({ variables: { input: { printerId, slot } } })
    return result.clearLoadedFilament.errors
  }, 'Filament removed')

  if (data && !data.printer) return null

  const title = (
    <span className={classes.filamentTitle}>
      <FilamentOutlined aria-hidden="true" />
      <h2 className={classes.cardTitle}>Loaded Filament</h2>
    </span>
  )
  if (error && !data) {
    return (
      <Card title={title}>
        <Alert type="error" showIcon title="Could not load the filament" description={error.message} />
      </Card>
    )
  }

  return (
    <Card title={title} loading={!data} onKeyDown={keepEnter}>
      <Form component={false} layout="vertical" requiredMark={false}>
        <div className={classes.grid2}>
          <Form.Item label="Material" htmlFor={`${id}material`} validateStatus={errors.material && 'error'}
            help={errors.material}>
            <Select id={`${id}material`} value={values.material} placeholder="Pick a material"
              options={data && materialOptions(data.filamentMaterials, data.printer.specs?.materials)}
              showSearch={{ optionFilterProp: 'label' }} disabled={Boolean(busy)}
              onChange={(material) => change('material', material)} />
          </Form.Item>
          <Form.Item label="Colour" htmlFor={`${id}colour`} validateStatus={errors.colour && 'error'}
            help={errors.colour}>
            <AutoComplete id={`${id}colour`} value={values.colour} placeholder="e.g. Galaxy Black"
              options={data?.filamentColours.map((colour) => ({ value: colour }))}
              showSearch={{ filterOption: filterColour }} disabled={Boolean(busy)}
              onChange={(colour) => change('colour', colour)} />
          </Form.Item>
        </div>
      </Form>

      {hint && <span className={`${classes.small} ${classes.filamentHint}`}>{hint}</span>}

      {changedElsewhere && (
        <Alert className={classes.changedElsewhere} type="info" showIcon
          title={loaded ? `Changed to ${loaded.material} · ${loaded.colour} in another window` : 'Removed in another window'} />
      )}

      <span className={classes.small}>Set this when you swap spools.</span>
      <div className={classes.filamentFooter}>
        <span className={classes.muted}>{loaded ? `Updated ${formatAgo(loaded.updatedAt, now)}` : 'No filament set'}</span>
        <div className={classes.buttons}>
          {loaded && (
            <Button type="text" onClick={remove} loading={busy === 'remove'} disabled={busy === 'update'}>
              Remove Filament
            </Button>
          )}
          <Button type="primary" onClick={update} loading={busy === 'update'}
            disabled={!edit || !complete || Boolean(busy)}>
            Update Filament
          </Button>
        </div>
      </div>
    </Card>
  )
}

LoadedFilament.propTypes = {
  printerId: PropTypes.string.isRequired,
  slot: PropTypes.number,
  demand: PropTypes.arrayOf(PropTypes.shape({
    slot: PropTypes.number.isRequired,
    material: PropTypes.string.isRequired,
    colour: PropTypes.string.isRequired,
    waitingJobsAskingCount: PropTypes.number
  }))
}
