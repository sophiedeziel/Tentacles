import React, { useState } from 'react'
import PropTypes from 'prop-types'
import { useLazyQuery, useQuery } from '@apollo/client/react'
import { Alert, Button, Card, Form, Input, Tag } from 'antd'

import { BACKENDS, testErrorAlert } from '../connection'
import { productName } from '../PrintersList/fleetView'
import { IDENTIFY_SAVED_PRINTER, PRINTER_VERSION } from './graphql/details'
import * as classes from './PrinterDetails.module.less'

// The connection a test ran with: its answer only shows while the form still holds it
const connectionKey = ({ uri, username, secret } = {}) => JSON.stringify([uri, username, secret])

// The server's version, read apart from the page (it calls the printer), or the one the last test read
function VersionLine ({ printer, testedVersion }) {
  const { data, loading } = useQuery(PRINTER_VERSION, { variables: { id: printer.id } })
  const version = testedVersion || data?.printer?.version
  let text = version
  if (!testedVersion && loading) text = 'Checking the version…'
  else if (!version || version === 'Unavailable') text = `${productName(printer.backend)} did not answer`
  return <span className={classes.muted}>{text}</span>
}

// Connection: the backend can't change (that's a new printer); the secret is never shown, blank keeps it. Test
// Connection tries what the form holds, with the saved secret when none is typed.
export default function ConnectionCard ({ printer }) {
  const form = Form.useFormInstance()
  const values = Form.useWatch([], form)
  const [identifyPrinter, { loading: testing }] = useLazyQuery(IDENTIFY_SAVED_PRINTER, { fetchPolicy: 'no-cache' })
  const [test, setTest] = useState(null)
  const { backend } = printer
  const settings = BACKENDS[backend]
  const result = test && test.key === connectionKey(values) ? test : null

  const testConnection = async () => {
    try {
      await form.validateFields(['uri'])
    } catch {
      return // the form shows what's missing
    }
    const { uri, username, secret } = form.getFieldsValue()
    const key = connectionKey({ uri, username, secret })
    const variables = {
      backend, uri, username: backend === 'PRUSALINK' ? username : null, secret: secret || null, printerId: printer.id
    }
    try {
      const { data, error } = await identifyPrinter({ variables })
      if (error) throw error
      setTest({ key, identity: data.identifyPrinter })
    } catch (error) {
      setTest({ key, error: testErrorAlert(error, backend) })
    }
  }

  return (
    <Card title={<h2 className={classes.cardTitle}>Connection</h2>}>
      <div className={classes.serverRow}>
        <span className={classes.strong}>Printer server</span>
        <Tag style={{ marginInlineEnd: 0 }}>{productName(backend)}</Tag>
      </div>

      <Form.Item label="Printer name" name="name" rules={[{ required: true, whitespace: true, message: 'Name is required' }]}>
        <Input />
      </Form.Item>

      <Form.Item label={settings.uriLabel} name="uri"
        rules={[
          { required: true, whitespace: true, message: `${settings.uriLabel} is required` },
          { type: 'url', message: `Enter a full address, e.g. ${settings.uriPlaceholder}` },
        ]}>
        <Input placeholder={settings.uriPlaceholder} />
      </Form.Item>

      {backend === 'PRUSALINK' && (
        <Form.Item label="Username" name="username">
          <Input placeholder="maker" />
        </Form.Item>
      )}

      <Form.Item label={settings.secretLabel} name="secret" extra={settings.savedSecretHelp}>
        <Input.Password placeholder={settings.savedSecretPlaceholder} autoComplete="new-password" />
      </Form.Item>

      <div className={classes.versionRow}>
        <VersionLine printer={printer} testedVersion={result?.identity?.version} />
        <Button onClick={testConnection} loading={testing}>Test Connection</Button>
      </div>

      {result?.identity && (
        <Alert className={classes.testResult} type="success" showIcon title="Connected"
          description={[result.identity.name, result.identity.version].filter(Boolean).join(', ')} />
      )}
      {result?.error && (
        <Alert className={classes.testResult} type="error" showIcon title={result.error.title}
          description={result.error.description} />
      )}
    </Card>
  )
}

const printerShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  backend: PropTypes.string.isRequired
}).isRequired

VersionLine.propTypes = { printer: printerShape, testedVersion: PropTypes.string }
ConnectionCard.propTypes = { printer: printerShape }
