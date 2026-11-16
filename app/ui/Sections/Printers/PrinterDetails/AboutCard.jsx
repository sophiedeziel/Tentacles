import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { Card, Form, Input, InputNumber, Select, Switch, Tag } from 'antd'

import { productName } from '../PrintersList/fleetView'
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

// One switch in its box, with a hint under its label
function SwitchField ({ label, name, extra }) {
  return (
    <div className={classes.switchBox}>
      <div className={classes.switchText}>
        <label htmlFor={`specs_${name}`} className={classes.strong}>{label}</label>
        {extra && <span className={classes.small}>{extra}</span>}
      </div>
      <Form.Item name={['specs', name]} valuePropName="checked" noStyle><Switch /></Form.Item>
    </div>
  )
}

// About This Printer: what the printer is and can do, in the page's form (Save Changes writes it)
export default function AboutCard ({ printer }) {
  const form = Form.useFormInstance()
  const specs = Form.useWatch('specs', form)
  const product = productName(printer.backend)
  const shape = specs?.bedShape || 'rectangular'
  const partialVolume = specs && volumeInput({ ...specs, bedShape: shape }) === undefined

  return (
    <Card className={classes.about}
      title={<span className={classes.title}><h2 className={classes.cardTitle}>About This Printer</h2><Tag>Optional</Tag></span>}>
      <div className={classes.banner}>
        <span className={classes.strong}>{product} can fill in some of these fields</span>
        <span className={classes.small}>
          Empty fields are filled in for you. A field that already has a value is never replaced, unless you click
          the reload icon next to it, and that reloads only that field.
        </span>
      </div>

      <div className={classes.grid2}>
        <Form.Item label="Brand" name={['specs', 'brand']} extra="Printer servers do not report a brand.">
          <Input />
        </Form.Item>
        <Form.Item label="Model" name={['specs', 'model']}><Input /></Form.Item>
        <Form.Item label="Firmware" name={['specs', 'firmware']}><FirmwareSelect /></Form.Item>
        <Form.Item label="Firmware version" name={['specs', 'firmwareVersion']}><Input /></Form.Item>
      </div>

      <h3 className={classes.capabilities}>Capabilities</h3>

      <Form.Item label="Build volume"
        help={partialVolume ? 'Fill in every dimension to save the build volume, or clear them all' : undefined}>
        <div role="group" aria-label="Build volume" className={classes.volume}>
          {VOLUME_INPUTS.map(({ name, label, prefix }) => (
            <Form.Item key={name} name={['specs', name]} noStyle hidden={!DIMENSIONS[shape].includes(name)}>
              <InputNumber aria-label={label} prefix={prefix} suffix="mm" min={0} className={classes.dimension} />
            </Form.Item>
          ))}
        </div>
      </Form.Item>

      <div className={classes.grid3}>
        <Form.Item label="Bed shape" name={['specs', 'bedShape']}><Select options={BED_SHAPES} /></Form.Item>
        <Form.Item label="Extruders" name={['specs', 'extruders']}>
          <InputNumber min={1} precision={0} className={classes.number} />
        </Form.Item>
        <Form.Item label="Nozzle diameter" name={['specs', 'nozzleDiameter']}>
          <InputNumber suffix="mm" min={0} step={0.1} className={classes.number} />
        </Form.Item>
      </div>

      <div className={classes.grid2}>
        <Form.Item label="Max hotend temperature" name={['specs', 'maxHotendTemp']}>
          <InputNumber suffix="°C" min={0} max={500} precision={0} className={classes.number} />
        </Form.Item>
        <Form.Item label="Max bed temperature" name={['specs', 'maxBedTemp']}>
          <InputNumber suffix="°C" min={0} max={500} precision={0} className={classes.number} />
        </Form.Item>
      </div>

      <div className={classes.grid3}>
        <SwitchField label="Heated bed" name="heatedBed" />
        <SwitchField label="Heated chamber" name="heatedChamber" />
        <SwitchField label="Webcam" name="webcam"
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
  extra: PropTypes.string
}

AboutCard.propTypes = {
  printer: PropTypes.shape({ backend: PropTypes.string.isRequired }).isRequired
}
