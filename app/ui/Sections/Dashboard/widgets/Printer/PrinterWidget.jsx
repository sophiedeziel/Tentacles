import React from 'react'
import PropTypes from 'prop-types'
import { Progress, Spin } from 'antd'

import PrinterStatus from '../../../../components/PrinterStatus/PrinterStatus'
import { Printer3DOutlined } from '../../../../components/icons'
import printerView from './printerView'
import * as classes from './PrinterWidget.module.less'

// The progress ring while a job is under way, a spinner while connecting, the state icon otherwise
export function StateVisual ({ view, background }) {
  if (view.ring) {
    return <Progress type="circle" percent={view.progress} size={view.ringSize} strokeColor={view.color} />
  }
  if (view.spin) return <Spin size={view.ringSize > 64 ? 'large' : 'default'} />
  return (
    <span className={classes.stateCircle} style={{
      width: view.iconCircle, height: view.iconCircle, fontSize: view.iconFont, background: background || view.tint
    }}>
      <PrinterStatus family={view.family} text={view.stateText} variant="icon" />
    </span>
  )
}

StateVisual.propTypes = {
  view: PropTypes.object.isRequired,
  background: PropTypes.string
}

function SmallLayout ({ view }) {
  return (
    <div className={classes.small}>
      <div className={classes.smallHeader}>
        <Printer3DOutlined />
        <span className={classes.smallName} title={view.name}>{view.name}</span>
      </div>
      <div className={classes.smallCenter}><StateVisual view={view} /></div>
      {view.showTime && <span className={classes.smallTime}>{view.timeText}</span>}
      <PrinterStatus family={view.family} text={view.stateText} variant="badge" />
    </div>
  )
}

// Medium with the camera on: the stream fills the tile, with the name, progress and time on a strip
function MediumCameraLayout ({ view, cameraStream }) {
  return (
    <div className={classes.cameraTile}>
      {view.cameraLive ? cameraStream : <div className={classes.cameraMessage}>{view.cameraMessage.message}</div>}
      <span className={classes.statePill}>
        <span className={classes.dot} style={{ background: view.color }} />{view.stateText}
      </span>
      <div className={classes.strip}>
        <div className={classes.stripTitle}>
          <span className={classes.ellipsis}>{view.name}</span>
          {view.ring && <span>{view.progress}%</span>}
        </div>
        <span className={classes.stripMeta}>{view.metaLine}</span>
      </div>
      {view.ring && <div className={classes.stripBar} style={{ width: `${view.progress}%`, background: view.color }} />}
    </div>
  )
}

function MediumLayout ({ view }) {
  return (
    <div className={classes.medium}>
      <div className={classes.visual}><StateVisual view={view} /></div>
      <div className={classes.details}>
        <span className={classes.name} title={view.name}>{view.name}</span>
        <span className={classes.headline}>{view.headline}</span>
        <span className={classes.meta}>{view.subline}</span>
        {view.showTemps && <span className={classes.meta}>{view.tempsLine}</span>}
      </div>
    </div>
  )
}

const LAYOUTS = { S: SmallLayout, M: MediumLayout }

// One printer's live state. Presentational: it renders from props only, so the Add Widget gallery can show it
// with fixture data.
// - printer: { id, name, status, canStartNext, nextJob } as the dashboard query returns it
// - size: 'S', 'M', 'L' or 'XL'; options: the widget's options; now: the dashboard's clock (re-renders the times)
// - cameraStream: the live stream element, shown when the camera is on and the printer reachable
export default function PrinterWidget ({ printer, size, options, now, cameraStream = null }) {
  const view = printerView({ printer, size, options, now })
  if (size === 'M' && view.camera) return <MediumCameraLayout view={view} cameraStream={cameraStream} />

  const Layout = LAYOUTS[size] || MediumLayout
  return <Layout view={view} />
}

PrinterWidget.propTypes = {
  printer: PropTypes.shape({
    id: PropTypes.string.isRequired,
    name: PropTypes.string.isRequired,
    status: PropTypes.object.isRequired,
    canStartNext: PropTypes.bool,
    nextJob: PropTypes.object
  }).isRequired,
  size: PropTypes.oneOf(['S', 'M', 'L', 'XL']).isRequired,
  options: PropTypes.shape({
    camera: PropTypes.bool,
    timeLeft: PropTypes.bool,
    temperatures: PropTypes.bool,
    upNext: PropTypes.bool,
    controls: PropTypes.bool
  }).isRequired,
  now: PropTypes.oneOfType([PropTypes.instanceOf(Date), PropTypes.number]).isRequired,
  cameraStream: PropTypes.node
}

const layoutPropTypes = { view: PropTypes.object.isRequired }
SmallLayout.propTypes = layoutPropTypes
MediumLayout.propTypes = layoutPropTypes
MediumCameraLayout.propTypes = { ...layoutPropTypes, cameraStream: PropTypes.node }
