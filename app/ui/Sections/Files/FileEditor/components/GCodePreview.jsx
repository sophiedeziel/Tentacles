import React, {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
  useState
} from 'react'
import PropTypes from 'prop-types'
import * as GCodePreview from 'gcode-preview'

import * as THREE from 'three'

function GCodePreviewUI (props, ref) {
  const {
    topLayerColor = '',
    lastSegmentColor = '',
    startLayer,
    endLayer,
    lineWidth,
    extrusionColor,
    travelColor,
    gcode
  } = props

  GCodePreviewUI.propTypes = {
    topLayerColor: PropTypes.string,
    lastSegmentColor: PropTypes.string,
    startLayer: PropTypes.number,
    endLayer: PropTypes.number,
    lineWidth: PropTypes.number,
    extrusionColor: PropTypes.string,
    travelColor: PropTypes.string,
    gcode: PropTypes.string
  }
  const canvasRef = useRef(null)
  const [preview, setPreview] = useState()

  const resizePreview = () => {
    preview?.resize()
  }

  useImperativeHandle(ref, () => ({
    getLayerCount () {
      return preview?.layers.length
    },
    processGCode (gcode) {
      preview?.processGCode(gcode)
    }
  }))

  useEffect(() => {
    const object = GCodePreview.init({
      canvas: canvasRef.current,
      startLayer,
      endLayer,
      lineWidth,
      topLayerColor: new THREE.Color(topLayerColor).getHex(),
      lastSegmentColor: new THREE.Color(lastSegmentColor).getHex(),
      extrusionColor: new THREE.Color(extrusionColor).getHex(),
      travelColor: new THREE.Color(travelColor).getHex(),
      buildVolume: { x: 230, y: 230, z: 300 },
      initialCameraPosition: [0, 400, 500],
      allowDragNDrop: false,
      allowCanvasClick: true,
      backgroundColor: 0xffffff
    })

    setPreview(object)

    object.processGCode(gcode)

    window.addEventListener('resize', resizePreview)

    return () => {
      window.removeEventListener('resize', resizePreview)
    }
  }, [])

  return (
    <div style={{ width: '100%' }}>
      <canvas style={{ width: '100%' }} ref={canvasRef}></canvas>
    </div>
  )
}

export default forwardRef(GCodePreviewUI)
