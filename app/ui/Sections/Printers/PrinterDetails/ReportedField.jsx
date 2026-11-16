import React from 'react'
import PropTypes from 'prop-types'
import { Button, Form } from 'antd'
import { ReloadOutlined } from '@ant-design/icons'

import * as classes from './PrinterDetails.module.less'

// The reload button of a field the printer's server reports: copies the reported value into the form
export function ReloadButton ({ label, product, onClick }) {
  return (
    <Button icon={<ReloadOutlined />} onClick={onClick} title={`Reload from ${product}`}
      aria-label={`Reload ${label.toLowerCase()} from ${product}`} />
  )
}

// A field that may show what the server reports: its hint under it, and a reload button beside it once there is
// one. The input keeps its place either way, so it never loses focus when the hint arrives.
export default function ReportedField ({ label, name, hint, product, onReload, extra, rules, children }) {
  return (
    <Form.Item label={label} htmlFor={[].concat(name).join('_')} extra={hint || extra}>
      <div className={classes.withReload}>
        <Form.Item name={name} rules={rules} noStyle>{children}</Form.Item>
        {hint && <ReloadButton label={label} product={product} onClick={onReload} />}
      </div>
    </Form.Item>
  )
}

ReloadButton.propTypes = {
  label: PropTypes.string.isRequired,
  product: PropTypes.string.isRequired,
  onClick: PropTypes.func.isRequired
}

ReportedField.propTypes = {
  label: PropTypes.string.isRequired,
  name: PropTypes.oneOfType([PropTypes.string, PropTypes.arrayOf(PropTypes.string)]).isRequired,
  hint: PropTypes.string,
  product: PropTypes.string.isRequired,
  onReload: PropTypes.func.isRequired,
  extra: PropTypes.node,
  rules: PropTypes.array,
  children: PropTypes.node.isRequired
}
