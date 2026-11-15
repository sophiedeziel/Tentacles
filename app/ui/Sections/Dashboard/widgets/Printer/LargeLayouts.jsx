import React from 'react'
import PropTypes from 'prop-types'
import { Button, Progress } from 'antd'

import PrinterStatus from '../../../../components/PrinterStatus/PrinterStatus'
import WebcamPlaceholder from '../../../../components/WebcamPlaceholder/WebcamPlaceholder'
import { PrintQueueOutlined } from '../../../../components/icons'
import StateVisual from './StateVisual'
import * as classes from './PrinterWidget.module.less'

// The live stream under a "Live" pill, or the placeholder saying why there is none
function CameraArea ({ view, cameraStream, style }) {
  if (!view.cameraLive) {
    return (
      <div className={classes.cameraOff} style={style}>
        <WebcamPlaceholder message={view.cameraMessage.message} hint={view.cameraMessage.hint} />
      </div>
    )
  }
  return (
    <div className={classes.cameraBox} style={style}>
      <span className={classes.livePill}><span className={classes.dot} style={{ background: '#ff4d4f' }} />Live</span>
      {cameraStream}
    </div>
  )
}

function Temperatures ({ view }) {
  return (
    <div className={classes.temps}>
      {view.temps.map((temp) => (
        <div key={temp.label} className={classes.temp}>
          <span className={classes.tempLabel}>{temp.label}</span>{temp.value}
        </div>
      ))}
    </div>
  )
}

function UpNext ({ view }) {
  return (
    <div className={classes.next}>
      <PrintQueueOutlined /><span className={classes.ellipsis}>{view.nextText}</span>
    </div>
  )
}

function plainAction (action) {
  return (
    <Button key={action.key} danger={action.danger} disabled={action.disabled} loading={action.loading}>
      {action.label}
    </Button>
  )
}

function Actions ({ view, renderAction = plainAction }) {
  return <div className={classes.actions}>{view.actions.map((action) => renderAction(action, view))}</div>
}

// Large: the camera above the job, or the ring beside it with the temperatures and up next
export function LargeLayout ({ view, cameraStream, renderAction }) {
  return (
    <div className={classes.large}>
      {view.camera
        ? <>
            <CameraArea view={view} cameraStream={cameraStream} style={{ height: 140 }} />
            <div className={classes.titleRow}>
              <span className={classes.name} title={view.name}>{view.name}</span>
              <PrinterStatus family={view.family} text={view.stateText} />
            </div>
            <span className={classes.headline}>{view.headline}</span>
            {view.ring && <Progress percent={view.progress} strokeColor={view.color} size="small" />}
            <span className={classes.meta}>{view.metaLine}</span>
          </>
        : <>
            <div className={classes.summary}>
              <div className={classes.largeVisual}><StateVisual view={view} /></div>
              <div className={classes.details}>
                <span className={classes.name} title={view.name}>{view.name}</span>
                <div style={{ display: 'flex' }}><PrinterStatus family={view.family} text={view.stateText} /></div>
                <span className={classes.headline}>{view.headline}</span>
              </div>
            </div>
            <span className={classes.meta}>{view.subline}</span>
            {view.showTemps && <Temperatures view={view} />}
            {view.showNext && <UpNext view={view} />}
          </>}
      {view.showActions && <Actions view={view} renderAction={renderAction} />}
    </div>
  )
}

// Extra Large: the camera (or a large ring on the state's tint) beside every detail
export function ExtraLargeLayout ({ view, cameraStream, renderAction }) {
  return (
    <div className={classes.extraLarge}>
      <div className={classes.xlVisual}>
        {view.camera
          ? <CameraArea view={view} cameraStream={cameraStream} />
          : <div className={classes.xlRing} style={{ background: view.tint }}><StateVisual view={view} background="#fff" /></div>}
      </div>
      <div className={classes.xlDetails}>
        <div className={classes.titleRow}>
          <span className={classes.xlName} title={view.name}>{view.name}</span>
          <PrinterStatus family={view.family} text={view.stateText} />
        </div>
        <span className={classes.headline}>{view.headline}</span>
        {view.progressBar && <Progress percent={view.progress} strokeColor={view.color} />}
        <span className={classes.meta}>{view.subline}</span>
        {view.showTemps && <Temperatures view={view} />}
        {view.showNext && <UpNext view={view} />}
        {view.showActions && <Actions view={view} renderAction={renderAction} />}
      </div>
    </div>
  )
}

const viewProps = { view: PropTypes.object.isRequired }
const layoutProps = { ...viewProps, cameraStream: PropTypes.node, renderAction: PropTypes.func }
CameraArea.propTypes = { ...viewProps, cameraStream: PropTypes.node, style: PropTypes.object }
Temperatures.propTypes = viewProps
UpNext.propTypes = viewProps
Actions.propTypes = { ...viewProps, renderAction: PropTypes.func }
LargeLayout.propTypes = layoutProps
ExtraLargeLayout.propTypes = layoutProps
