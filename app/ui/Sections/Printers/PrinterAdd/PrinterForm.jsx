import React, { useRef, useState } from 'react'
import { useLazyQuery, useMutation } from '@apollo/client/react'
import { CombinedGraphQLErrors } from '@apollo/client'
import { Alert, Button, Form, Input, Radio, Space } from 'antd'

import IdentifyPrinter from './graphql/IdentifyPrinter.graphql'
import AddPrinter from './graphql/AddPrinter.graphql'

const BACKENDS = {
  OCTOPRINT: {
    uriLabel: 'URI',
    uriPlaceholder: 'http://octopi.local',
    secretLabel: 'API key',
    wrongSecret: 'Wrong API key'
  },
  PRUSALINK: {
    uriLabel: 'Address',
    uriPlaceholder: 'http://192.168.1.42',
    secretLabel: 'Password',
    secretHelp: 'Shown on the printer: Settings > Network > PrusaLink',
    wrongSecret: 'Wrong password'
  }
}

// Changing one of these invalidates the connection test
const CONNECTION_FIELDS = ['backend', 'uri', 'username', 'secret']

// identifyPrinter's failures are GraphQL errors with a code in `extensions.code`
const testErrorAlert = (error, backend) => {
  const graphQLError = CombinedGraphQLErrors.is(error) ? error.errors[0] : null
  const description = graphQLError?.message || error.message

  switch (graphQLError?.extensions?.code) {
    case 'UNAUTHORIZED': return { title: BACKENDS[backend].wrongSecret, description }
    case 'UNREACHABLE': return { title: 'Printer not reachable', description }
    default: return { title: description }
  }
}

// The manual "Add a printer" form: test the connection, then add the printer
export default function PrinterForm () {
  const [form] = Form.useForm()
  const backend = Form.useWatch('backend', form) || 'OCTOPRINT'
  const [identity, setIdentity] = useState(null)
  const [testError, setTestError] = useState(null)
  const [addErrors, setAddErrors] = useState([])
  // Ignores the answer of a test whose connection fields have changed since
  const testId = useRef(0)

  const [identifyPrinter, { loading: testing }] = useLazyQuery(IdentifyPrinter, { fetchPolicy: 'no-cache' })
  const [addPrinter, { loading: adding }] = useMutation(AddPrinter)

  const resetTest = () => {
    testId.current += 1
    setIdentity(null)
    setTestError(null)
  }

  const handleValuesChange = (changedValues) => {
    setAddErrors([])
    if (CONNECTION_FIELDS.some((field) => field in changedValues)) resetTest()
  }

  const testConnection = () => {
    form.validateFields(backend === 'PRUSALINK' ? ['uri', 'username', 'secret'] : ['uri', 'secret']).then(() => {
      resetTest()
      const id = testId.current
      const { uri, username, secret } = form.getFieldsValue()
      const variables = { backend, uri, secret, username: backend === 'PRUSALINK' ? username : null }

      identifyPrinter({ variables }).then(({ data, error }) => {
        if (error) throw error
        if (id !== testId.current) return

        setIdentity(data.identifyPrinter)
        if (!form.getFieldValue('name') && data.identifyPrinter.name) {
          form.setFieldsValue({ name: data.identifyPrinter.name })
        }
      }).catch((error) => {
        if (id === testId.current) setTestError(testErrorAlert(error, backend))
      })
    }).catch(() => {}) // the form shows the missing fields
  }

  const handleFinish = ({ name, uri, username, secret }) => {
    if (!identity) return // e.g. Enter in a field before the test passed

    const input = { backend, name, uri, secret, username: backend === 'PRUSALINK' ? username : null }

    addPrinter({ variables: { input } }).then(({ data, error }) => {
      if (error) throw error
      const { errors } = data.addPrinter
      if (errors.length > 0) {
        setAddErrors(errors)
        return
      }
      window.location.href = '/printers/manage'
    }).catch((error) => {
      setAddErrors([error.message])
    })
  }

  const settings = BACKENDS[backend]

  return (
    <Form
      form={form}
      layout="vertical"
      initialValues={{ backend: 'OCTOPRINT', username: 'maker' }}
      onValuesChange={handleValuesChange}
      onFinish={handleFinish}
    >
      <Form.Item label="Printer server" name="backend">
        <Radio.Group>
          <Radio.Button value="OCTOPRINT">OctoPrint</Radio.Button>
          <Radio.Button value="PRUSALINK">PrusaLink</Radio.Button>
        </Radio.Group>
      </Form.Item>

      <Form.Item label="Printer name" name="name" rules={[{ required: true, message: 'Name is required' }]}>
        <Input />
      </Form.Item>

      <Form.Item label={settings.uriLabel} name="uri" rules={[{ required: true, message: `${settings.uriLabel} is required` }]}>
        <Input placeholder={settings.uriPlaceholder} />
      </Form.Item>

      {backend === 'PRUSALINK' && (
        <Form.Item label="Username" name="username" rules={[{ required: true, message: 'Username is required' }]}>
          <Input />
        </Form.Item>
      )}

      <Form.Item
        label={settings.secretLabel}
        name="secret"
        extra={settings.secretHelp}
        rules={[{ required: true, message: `${settings.secretLabel} is required` }]}
      >
        {backend === 'PRUSALINK' ? <Input.Password /> : <Input />}
      </Form.Item>

      {identity && (
        <Form.Item>
          <Alert type="success" showIcon title="Connected" description={[identity.name, identity.version].filter(Boolean).join(', ')} />
        </Form.Item>
      )}

      {testError && (
        <Form.Item>
          <Alert type="error" showIcon title={testError.title} description={testError.description} />
        </Form.Item>
      )}

      {addErrors.length > 0 && (
        <Form.Item>
          <Alert type="error" showIcon title="The printer was not added" description={addErrors.join('. ')} />
        </Form.Item>
      )}

      <Form.Item>
        <Space>
          <Button onClick={testConnection} loading={testing}>
            Test connection
          </Button>
          <Button type="primary" htmlType="submit" disabled={!identity} loading={adding}>
            Add printer
          </Button>
        </Space>
      </Form.Item>
    </Form>
  )
}
