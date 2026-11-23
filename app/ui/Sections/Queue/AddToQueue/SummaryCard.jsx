import React from 'react'
import PropTypes from 'prop-types'
import { Card, Skeleton, Typography, theme } from 'antd'

import { formatTimeLeft } from '../../../utils/time'
import { FilamentLine } from '../parts'
import whatHappensNext from '../whatHappensNext'
import { summaryView } from './formRules'
import * as classes from './AddToQueue.module.less'

const { Text } = Typography

function Row ({ label, title, detail, children }) {
  return (
    <div className={classes.summaryRow}>
      <dt><Text type="secondary">{label}</Text></dt>
      <dd>
        <span className={classes.strong}>{title}</span>
        {detail && <Text type="secondary" className={classes.small}>{detail}</Text>}
        {children}
      </dd>
    </div>
  )
}

// Starts: what happens to the job first, in the queue page's words (whatHappensNext.js), read on a job made of the
// form. "In about 5 h" over those words once the server knows when (startsAt: null until the queue simulation).
function Starts ({ starts, job, now }) {
  if (!starts) return <Row label="Starts" title="Not known" />
  const reason = whatHappensNext({ ...job, whatHappensNext: starts })?.text ?? 'Not known'
  if (!starts.startsAt) return <Row label="Starts" title={reason} />
  const left = new Date(starts.startsAt).getTime() - now
  return <Row label="Starts" title={left > 60000 ? `In about ${formatTimeLeft(left)}` : 'Now'} detail={reason} />
}

// The Summary: the queue now, when it starts, the filament and the print time of its copies (queueEstimate), over the
// form's buttons. `job`: what the form describes, as whatHappensNext reads a print job (copies, same printer, the
// printers that can print it, its needs). `readyPrinters`: the selected printers ready to print it.
export default function SummaryCard ({ estimate, job, readyPrinters, children }) {
  const { token } = theme.useToken()
  const view = estimate && summaryView(estimate, { samePrinter: job.samePrinter, readyPrinters })

  return (
    <section aria-label="Summary" className={classes.summary}>
      <Card title={<span className={classes.cardTitle}><h2>Summary</h2></span>} className={classes.card}
        style={{ borderColor: token.colorPrimaryBorder }}>
        {view
          ? (
            <dl className={classes.summaryRows}>
              <Row label="Queue now" title={view.queueNow.title} detail={view.queueNow.detail} />
              <Starts starts={estimate.starts} job={job} now={Date.now()} />
              <Row label="Filament" title={view.filament.title}>
                {view.filament.lines.map((line) => (
                  <span key={line.key} className={`${classes.filamentLine} ${classes.small}`}>
                    <FilamentLine filament={line} small
                      prefix={view.filament.lines.length > 1 ? `T${line.key}` : undefined} />
                    {line.amount && <Text type="secondary" className={classes.small}>{line.amount}</Text>}
                  </span>
                ))}
              </Row>
              <Row label="Print time" title={view.printTime.title} detail={view.printTime.detail} />
            </dl>
            )
          : <Skeleton active title={false} paragraph={{ rows: 6 }} />}
        <div className={classes.buttons}>{children}</div>
      </Card>
    </section>
  )
}

Row.propTypes = { label: PropTypes.string.isRequired, title: PropTypes.node, detail: PropTypes.node, children: PropTypes.node }
Starts.propTypes = {
  starts: PropTypes.shape({ startsAt: PropTypes.string }),
  job: PropTypes.object.isRequired,
  now: PropTypes.number.isRequired
}
SummaryCard.propTypes = {
  estimate: PropTypes.shape({
    printing: PropTypes.number.isRequired,
    waitingJobs: PropTypes.number.isRequired,
    jobsAhead: PropTypes.number.isRequired,
    printsAhead: PropTypes.number.isRequired,
    copiesToPrint: PropTypes.number.isRequired,
    filaments: PropTypes.array.isRequired,
    filamentGrams: PropTypes.number,
    filamentMetres: PropTypes.number,
    printSeconds: PropTypes.number,
    starts: PropTypes.object
  }),
  job: PropTypes.shape({ samePrinter: PropTypes.bool.isRequired }).isRequired,
  readyPrinters: PropTypes.number.isRequired,
  children: PropTypes.node
}
