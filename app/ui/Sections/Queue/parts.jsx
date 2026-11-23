import React from 'react'
import PropTypes from 'prop-types'
import { Card, Typography, theme } from 'antd'
import { Link } from 'react-router'

import { filamentLabel, swatchColour } from './queueView'
import * as classes from './QueuePage.module.less'

const { Text } = Typography

// Secondary text, in the theme's secondary colour
export function Muted ({ children, small = false }) {
  return <Text type="secondary" className={small ? classes.small : undefined}>{children}</Text>
}

// A cell's main line over a smaller, secondary one ("4 printers" / "All that can print it")
export function TwoLines ({ title, detail, strong = false }) {
  return (
    <div className={classes.cell}>
      <span className={strong ? classes.strong : undefined}>{title}</span>
      {detail && <Muted small>{detail}</Muted>}
    </div>
  )
}

// One section of the page: a card titled with the section's name and a line about it (`summary`, or `count`), its
// `tags`, and `extra` on the right, over its table. A landmark named after the title, so each section can be found on
// its own. `footer`: lines under the table.
export function QueueSection ({ title, summary, count, tags, extra, footer, children }) {
  const line = summary ?? count
  const heading = (
    <span className={classes.sectionTitle}>
      <h2>{title}</h2>
      {line != null && <Text type="secondary" className={classes.count}>{line}</Text>}
      {tags}
    </span>
  )

  return (
    <section aria-label={title}>
      <Card title={heading} extra={extra} className={classes.card} styles={{ body: { padding: 0 } }}>
        {children}
        {footer}
      </Card>
    </section>
  )
}

// A link to a page of the app, in the theme's primary colour (antd's own links take its info blue)
export function QueueLink ({ to, style, ...props }) {
  const { token } = theme.useToken()
  return <Link to={to} style={{ color: token.colorPrimary, ...style }} {...props} />
}

// A file's name: a link to its page, plain text once the file is deleted
export function FileName ({ file }) {
  if (file.isDeleted) return <Text className={classes.ellipsis} title={file.filename}>{file.filename}</Text>
  return <QueueLink to={`/files/${file.id}`} className={classes.ellipsis} title={file.filename}>{file.filename}</QueueLink>
}

// A filament's colour as a dot: filled with it when CSS knows its name, an outline otherwise. Any colour has none.
export function FilamentDot ({ colour }) {
  const { token } = theme.useToken()
  if (!colour) return null
  return (
    <span aria-hidden className={classes.dot}
      style={{ background: swatchColour(colour) || 'transparent', borderColor: token.colorBorder }} />
  )
}

// "● PLA · Black": a filament, its colour's dot first. `prefix`: the tool of a multi-tool job ("T1").
export function FilamentLine ({ filament, prefix, small = false }) {
  const label = `${prefix ? `${prefix} ` : ''}${filamentLabel(filament)}`
  return (
    <span className={`${classes.filament} ${small ? classes.small : ''}`}>
      <FilamentDot colour={filament.colour} />
      {small ? <Muted small>{label}</Muted> : label}
    </span>
  )
}

const printerShape = PropTypes.shape({ id: PropTypes.string.isRequired, name: PropTypes.string.isRequired })
const filamentShape = PropTypes.shape({ material: PropTypes.string, colour: PropTypes.string })

Muted.propTypes = { children: PropTypes.node, small: PropTypes.bool }
TwoLines.propTypes = { title: PropTypes.node.isRequired, detail: PropTypes.node, strong: PropTypes.bool }
QueueSection.propTypes = {
  title: PropTypes.string.isRequired,
  summary: PropTypes.node,
  count: PropTypes.number,
  tags: PropTypes.node,
  extra: PropTypes.node,
  footer: PropTypes.node,
  children: PropTypes.node.isRequired
}
QueueLink.propTypes = { to: PropTypes.string.isRequired, style: PropTypes.object }
FileName.propTypes = {
  file: PropTypes.shape({ id: PropTypes.string.isRequired, filename: PropTypes.string.isRequired, isDeleted: PropTypes.bool })
    .isRequired
}
FilamentDot.propTypes = { colour: PropTypes.string }
FilamentLine.propTypes = { filament: filamentShape.isRequired, prefix: PropTypes.string, small: PropTypes.bool }

export { printerShape }
