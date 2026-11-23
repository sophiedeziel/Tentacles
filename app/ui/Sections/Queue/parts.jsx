import React from 'react'
import PropTypes from 'prop-types'
import { Card, Typography } from 'antd'
import { Link } from 'react-router'

import PrinterAvatar from '../../components/PrinterAvatar/PrinterAvatar'
import * as classes from './QueuePage.module.less'

const { Text } = Typography

// Secondary text, in the theme's secondary colour
export function Muted ({ children, small = false }) {
  return <Text type="secondary" className={small ? classes.small : undefined}>{children}</Text>
}

// One section of the page: a card titled with the section's name (and how many rows it has), over its table.
// A landmark named after the title, so each section can be found on its own.
export function QueueSection ({ title, count, tags, extra, children }) {
  const heading = (
    <span className={classes.sectionTitle}>
      <h2>{title}</h2>
      {count != null && <Text type="secondary" className={classes.count}>{count}</Text>}
      {tags}
    </span>
  )

  return (
    <section aria-label={title}>
      <Card title={heading} extra={extra} className={classes.card} styles={{ body: { padding: 0 } }}>
        {children}
      </Card>
    </section>
  )
}

// A printer: its avatar, its name (a link to its page) and a line under it
export function PrinterCell ({ printer, subtitle }) {
  return (
    <div className={classes.printer}>
      <PrinterAvatar printer={printer} />
      <div className={classes.names}>
        <Link to={`/printers/${printer.id}`} className={classes.name}>{printer.name}</Link>
        {subtitle && <Muted small>{subtitle}</Muted>}
      </div>
    </div>
  )
}

// A file's name: a link to its page, plain text once the file is deleted
export function FileName ({ file }) {
  if (file.isDeleted) return <Text className={classes.ellipsis} title={file.filename}>{file.filename}</Text>
  return <Link to={`/files/${file.id}`} className={classes.ellipsis} title={file.filename}>{file.filename}</Link>
}

const printerShape = PropTypes.shape({ id: PropTypes.string.isRequired, name: PropTypes.string.isRequired })

Muted.propTypes = { children: PropTypes.node, small: PropTypes.bool }
QueueSection.propTypes = {
  title: PropTypes.string.isRequired,
  count: PropTypes.number,
  tags: PropTypes.node,
  extra: PropTypes.node,
  children: PropTypes.node.isRequired
}
PrinterCell.propTypes = { printer: printerShape.isRequired, subtitle: PropTypes.node }
FileName.propTypes = {
  file: PropTypes.shape({ id: PropTypes.string.isRequired, filename: PropTypes.string.isRequired, isDeleted: PropTypes.bool })
    .isRequired
}

export { printerShape }
