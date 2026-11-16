import React, { useEffect, useRef, useState } from 'react'
import PropTypes from 'prop-types'
import { Link, useBlocker, useNavigate, useParams } from 'react-router'
import { useApolloClient, useMutation, useQuery } from '@apollo/client/react'
import { Alert, App, Button, Form, Modal, Skeleton, Typography } from 'antd'
import { ArrowLeftOutlined, StarFilled, StarOutlined } from '@ant-design/icons'

import PrinterStatus from '../../../components/PrinterStatus/PrinterStatus'
import useFleetLiveUpdates from '../../../utils/useFleetLiveUpdates'
import { forgetPrinter } from '../PrintersList/RowMenu'
import useFavorite from '../useFavorite'
import AboutCard from './AboutCard'
import ConnectionCard from './ConnectionCard'
import RemoveCard from './RemoveCard'
import { formValues, hasChanges, updateInput } from './detailsForm'
import { reloadedValues, reportedValues, specsHints } from './specsHints'
import { IDENTIFY_SAVED_PRINTER, PRINTER_DETAILS, REPORTED_SPECS, UPDATE_PRINTER } from './graphql/details'
import * as classes from './PrinterDetails.module.less'

// Saved on click, apart from the form
function FavoriteButton ({ printer }) {
  const toggle = useFavorite(printer)
  return (
    <Button aria-pressed={printer.favorite} onClick={toggle}
      icon={printer.favorite ? <StarFilled className={classes.starOn} /> : <StarOutlined />}>
      {printer.favorite ? 'Favorite' : 'Add to Favorites'}
    </Button>
  )
}

// Warns before leaving with unsaved changes: a modal for the app's own links (react-router's blocker), the
// browser's dialog when the tab closes or reloads. `leaving` lets the page go once it means to (removed printer).
function useUnsavedChangesGuard (dirty, leaving) {
  const blocker = useBlocker(({ currentLocation, nextLocation }) =>
    dirty && !leaving.current && currentLocation.pathname !== nextLocation.pathname)

  useEffect(() => {
    if (!dirty) return
    const warn = (event) => {
      event.preventDefault()
      event.returnValue = ''
    }
    window.addEventListener('beforeunload', warn)
    return () => window.removeEventListener('beforeunload', warn)
  }, [dirty])

  return blocker
}

// What the printer's server reports, in the form's shape, read after the page renders: reportedSpecs, and the name
// identifyPrinter reads with the saved connection. Null until one of them answers; a failure is no answer.
function useReported (printer) {
  const { id, backend, uri, username } = printer
  const { data: specs } = useQuery(REPORTED_SPECS, { variables: { id } })
  const identity = { backend, uri, username: backend === 'PRUSALINK' ? username : null, secret: null, printerId: id }
  const { data: identified } = useQuery(IDENTIFY_SAVED_PRINTER, { variables: identity, skip: !uri })
  const reportedSpecs = specs?.printer?.reportedSpecs
  const name = identified?.identifyPrinter?.name
  return reportedSpecs || name ? reportedValues(reportedSpecs, name) : null
}

// One form for the whole page: Save Changes sends what changed in one updatePrinter. Favorite and Remove act at once.
function DetailsForm ({ printer }) {
  const { message } = App.useApp()
  const client = useApolloClient()
  const navigate = useNavigate()
  const [form] = Form.useForm()
  const values = Form.useWatch([], form)
  const [updatePrinter, { loading: saving }] = useMutation(UPDATE_PRINTER)
  const leaving = useRef(false)
  const dirty = hasChanges(printer, values)
  const blocker = useUnsavedChangesGuard(dirty, leaving)
  const [initialValues] = useState(() => formValues(printer))
  const reported = useReported(printer)
  const hints = specsHints(printer.backend, values, reported)
  const { status } = printer

  // Save Changes writes it
  const reload = (field) => form.setFieldsValue(reloadedValues(field, reported))

  const save = async (submitted) => {
    const input = updateInput(printer, submitted)
    if (Object.keys(input).length === 0) return
    try {
      const { data } = await updatePrinter({ variables: { input: { id: printer.id, ...input } } })
      const { printer: saved, errors } = data.updatePrinter
      if (errors.length > 0) {
        errors.forEach((error) => message.error(error))
        return
      }
      form.setFieldsValue(formValues({ ...printer, ...saved }))
      message.success('Changes saved')
    } catch (error) {
      message.error(`Could not save the changes: ${error.message}`)
    }
  }

  // Leaves first, so the page's query never asks the server for the printer it just removed
  const onRemoved = async (id) => {
    leaving.current = true
    await navigate('/printers/manage', { flushSync: true })
    forgetPrinter(client.cache, id)
  }

  return (
    <Form form={form} layout="vertical" requiredMark={false} initialValues={initialValues} onFinish={save}
      className={classes.page}>
      <div className={classes.header}>
        <div className={classes.heading}>
          <Link to="/printers/manage" className={classes.back}><ArrowLeftOutlined /> Printers</Link>
          <div className={classes.title}>
            <Typography.Title level={3} style={{ margin: 0 }}>{printer.name}</Typography.Title>
            <PrinterStatus family={status.stateFamily} text={status.stateText} />
          </div>
        </div>
        <div className={classes.buttons}>
          <FavoriteButton printer={printer} />
          <Button onClick={() => navigate(`/printers/${printer.id}/queue`)}>Open Queue</Button>
          <Button type="primary" htmlType="submit" loading={saving} disabled={!dirty}>Save Changes</Button>
        </div>
      </div>

      <div className={classes.columns}>
        <div className={classes.side}>
          <ConnectionCard printer={printer} nameHint={hints.name} onReload={reload} />
          <RemoveCard printer={printer} onRemoved={onRemoved} />
        </div>
        <AboutCard printer={printer} hints={hints} onReload={reload} />
      </div>

      <Modal open={blocker.state === 'blocked'} title="Leave without saving?" okText="Discard Changes"
        cancelText="Keep Editing" okButtonProps={{ danger: true }} onOk={() => blocker.proceed()}
        onCancel={() => blocker.reset()} centered width={400}>
        Your changes to {printer.name} are not saved.
      </Modal>
    </Form>
  )
}

function DetailsPage () {
  const { id } = useParams()
  // cache-and-network: never edits (or shows the state of) a printer cached earlier
  const { data, error, refetch } = useQuery(PRINTER_DETAILS, { variables: { id }, fetchPolicy: 'cache-and-network' })
  useFleetLiveUpdates(refetch)

  if (error && !data) return <Alert type="error" title="Could not load the printer" description={error.message} />
  if (!data) return <Skeleton active />
  if (!data.printer) {
    return (
      <Alert type="warning" showIcon title="Printer not found"
        description={<>It may have been removed. <Link to="/printers/manage">Back to Printers</Link></>} />
    )
  }
  // A new form for another printer
  return <DetailsForm key={data.printer.id} printer={data.printer} />
}

const printerShape = PropTypes.shape({
  id: PropTypes.string.isRequired,
  name: PropTypes.string.isRequired,
  backend: PropTypes.string.isRequired,
  favorite: PropTypes.bool,
  status: PropTypes.shape({ stateFamily: PropTypes.string.isRequired, stateText: PropTypes.string.isRequired })
}).isRequired

FavoriteButton.propTypes = { printer: printerShape }
DetailsForm.propTypes = { printer: printerShape }

// A printer's page, at /printers/:id: its live state in the header, its connection and About This Printer to edit
// in one form, and Remove.
export default function PrinterDetails () {
  return <App><DetailsPage /></App>
}
