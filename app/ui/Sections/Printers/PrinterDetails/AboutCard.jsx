import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { Card, Form, Input, InputNumber, Select, Switch, Tag } from 'antd'

import { productName } from '../PrintersList/fleetView'
import ReportedField, { ReloadButton } from './ReportedField'
import { DIMENSIONS, firmwareOptions, volumeInput } from './detailsForm'
import * as classes from './PrinterDetails.module.less'

const BED_SHAPES = [{ value: 'rectangular', label: 'Rectangular' }, { value: 'circular', label: 'Circular' }]
const MATERIALS = ['PLA', 'PETG', 'ABS', 'ASA', 'TPU'].map((material) => ({ value: material, label: material }))
const VOLUME_INPUTS = [
  { name: 'x', label: 'Width (X)', prefix: 'X' },
  { name: 'y', label: 'Depth (Y)', prefix: 'Y' },
  { name: 'diameter', label: 'Diameter', prefix: 'Ø' },
  { name: 'z', label: 'Height (Z)', prefix: 'Z' }
]

// Suggests the known firmwares and takes any typed text (saved as typed)
function FirmwareSelect ({ value, onChange, ...props }) {
  const [typed, setTyped] = useState('')
  return (
    <Select {...props} value={value} allowClear placeholder="Pick one or type its name"
      options={firmwareOptions(value, typed)}
      showSearch={{ searchValue: typed, onSearch: setTyped, optionFilterProp: 'label' }}
      onChange={(firmware) => {
        setTyped('')
        onChange(firmware ?? null)
      }} />
  )
}

// One switch in its box, with what the server reports (or another hint) under its label
function SwitchField ({ label, name, hint, extra, product, onReload }) {
  return (
    <div className={classes.switchBox}>
      <div className={classes.switchText}>
        <label htmlFor={`specs_${name}`} className={classes.strong}>{label}</label>
        {(hint || extra) && <span className={classes.small}>{hint || extra}</span>}
      </div>
      <div className={classes.withReload}>
        {hint && <ReloadButton label={label} product={product} onClick={() => onReload(name)} />}
        <Form.Item name={['specs', name]} valuePropName="checked" noStyle><Switch /></Form.Item>
      </div>
    </div>
  )
}

// About This Printer: what the printer is and can do, in the page's form (Save Changes writes it). `hints` holds
// what its server reports, per field; `onReload(field)` copies a reported value into the form. `narrow`: in the
// page's side column (the global queue's layout), where its rows of three fields and switches stack.
export default function AboutCard ({ printer, hints, onReload, narrow = false }) {
  const form = Form.useFormInstance()
  const specs = Form.useWatch('specs', form)
  const product = productName(printer.backend)
  const shape = specs?.bedShape || 'rectangular'
  const partialVolume = specs && volumeInput({ ...specs, bedShape: shape }) === undefined
  const field = (name) => ({ name: ['specs', name], hint: hints[name], product, onReload: () => onReload(name) })

  return (
    <Card className={narrow ? `${classes.about} ${classes.narrow}` : classes.about}
      title={<span className={classes.title}><h2 className={classes.cardTitle}>About This Printer</h2><Tag>Optional</Tag></span>}>
      <div className={classes.banner}>
        <span className={classes.strong}>{product} can fill in some of these fields</span>
        <span className={classes.small}>
          Empty fields are filled in from {product} when Tentacles first reaches the printer, and again when its
          address changes. A field that already has a value is never replaced, unless you click the reload icon next
          to it, and that reloads only that field.
        </span>
      </div>

      <div className={classes.grid2}>
        <Form.Item label="Brand" name={['specs', 'brand']} extra="Printer servers do not report a brand.">
          <Input />
        </Form.Item>
        <ReportedField label="Model" {...field('model')}><Input /></ReportedField>
        <ReportedField label="Firmware" {...field('firmware')}><FirmwareSelect /></ReportedField>
        <ReportedField label="Firmware version" {...field('firmwareVersion')}><Input /></ReportedField>
      </div>

      <h3 className={classes.capabilities}>Capabilities</h3>

      <Form.Item label="Build volume" extra={hints.buildVolume}
        help={partialVolume ? 'Fill in every dimension to save the build volume, or clear them all' : undefined}>
        <div role="group" aria-label="Build volume" className={classes.volume}>
          {VOLUME_INPUTS.map(({ name, label, prefix }) => (
            <Form.Item key={name} name={['specs', name]} noStyle hidden={!DIMENSIONS[shape].includes(name)}>
              <InputNumber aria-label={label} prefix={prefix} suffix="mm" min={0} className={classes.dimension} />
            </Form.Item>
          ))}
          {hints.buildVolume && <ReloadButton label="Build volume" product={product} onClick={() => onReload('buildVolume')} />}
        </div>
      </Form.Item>

      <div className={classes.grid3}>
        <Form.Item label="Bed shape" name={['specs', 'bedShape']}><Select options={BED_SHAPES} /></Form.Item>
        <ReportedField label="Extruders" {...field('extruders')}>
          <InputNumber min={1} precision={0} className={classes.number} />
        </ReportedField>
        <ReportedField label="Nozzle diameter" {...field('nozzleDiameter')}>
          <InputNumber suffix="mm" min={0} step={0.1} className={classes.number} />
        </ReportedField>
      </div>

      <div className={classes.grid2}>
        <Form.Item label="Max hotend temperature" name={['specs', 'maxHotendTemp']}>
          <InputNumber suffix="°C" min={0} max={500} precision={0} className={classes.number} />
        </Form.Item>
        <Form.Item label="Max bed temperature" name={['specs', 'maxBedTemp']}>
          <InputNumber suffix="°C" min={0} max={500} precision={0} className={classes.number} />
        </Form.Item>
      </div>

      <div className={`${classes.grid3} ${classes.switches}`}>
        <SwitchField label="Heated bed" name="heatedBed" hint={hints.heatedBed} product={product} onReload={onReload} />
        <SwitchField label="Heated chamber" name="heatedChamber" hint={hints.heatedChamber} product={product}
          onReload={onReload} />
        <SwitchField label="Webcam" name="webcam" hint={hints.webcam} product={product} onReload={onReload}
          extra={printer.backend === 'PRUSALINK' ? 'PrusaLink cameras are not read yet' : null} />
      </div>

      <Form.Item label="Materials" name={['specs', 'materials']} extra="Pick from the list or type your own.">
        <Select mode="tags" options={MATERIALS} placeholder="Add the materials this printer can run" />
      </Form.Item>
    </Card>
  )
}

FirmwareSelect.propTypes = { value: PropTypes.string, onChange: PropTypes.func }

SwitchField.propTypes = {
  label: PropTypes.string.isRequired,
  name: PropTypes.string.isRequired,
  hint: PropTypes.string,
  extra: PropTypes.string,
  product: PropTypes.string.isRequired,
  onReload: PropTypes.func.isRequired
}

AboutCard.propTypes = {
  printer: PropTypes.shape({ backend: PropTypes.string.isRequired }).isRequired,
  hints: PropTypes.objectOf(PropTypes.string).isRequired,
  onReload: PropTypes.func.isRequired,
  narrow: PropTypes.bool
}
