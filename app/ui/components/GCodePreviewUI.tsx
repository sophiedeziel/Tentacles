import * as GCodePreview from 'gcode-preview';
import React from 'react';
import {
  forwardRef,
  Ref,
  useEffect,
  useImperativeHandle,
  useRef,
  useState
} from 'react';
import { render } from 'react-dom';
import * as THREE from 'three';

interface GCodePreviewProps {
  topLayerColor?: string;
  lastSegmentColor?: string;
  startLayer?: number;
  endLayer?: number;
  lineWidth?: number;
  renderTubes?: boolean;
  gcode?: string;
}

interface GCodePreviewHandle {
  getLayerCount: () => number;
  processGCode: (gcode: string | string[]) => void;
  replaceGCode: (gcode: string | string[]) => void;
  render(): void;
}

function GCodePreviewUI(
  props: GCodePreviewProps,
  ref: Ref<GCodePreviewHandle>
): JSX.Element {
  const {
    topLayerColor = '',
    lastSegmentColor = '',
    startLayer,
    endLayer,
    lineWidth,
    renderTubes,
    gcode
  } = props;
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [preview, setPreview] = useState<GCodePreview.WebGLPreview>();

  useEffect(() => {
    if (!preview) return
    console.log("changed")
    preview.endLayer = endLayer
    // console.log(preview)
    preview.render()
  }, [endLayer, startLayer, lineWidth, topLayerColor, lastSegmentColor]);

  const resizePreview = () => {
    preview?.resize();
    console.log("resize")
  };

  useImperativeHandle(ref, () => ({
    getLayerCount() {
      console.log("getLayerCount");
      return preview?.layers?.length as number;
    },
    processGCode(gcode) {
      console.log("processGCode");
      preview?.processGCode(gcode);
    },
    replaceGCode(gcode) {
      console.log("replaceGCode");
      preview?.clear();
      preview?.processGCode(gcode);
    },
    render() {
      console.log("render");
      preview?.render();
    }
  }));

  useEffect(() => {
    if (!gcode) return;
    console.log("gcode changed")
    preview?.clear();
    preview?.processGCode(gcode);
}, [gcode, preview]);

  useEffect(() => {
    setPreview(
      GCodePreview.init({
        canvas: canvasRef.current as HTMLCanvasElement,
        startLayer,
        endLayer,
        lineWidth,
        buildVolume: { x: 250, y: 220, z: 150 },
        initialCameraPosition: [0, 200, 400],
        allowDragNDrop: false,
        renderTubes: renderTubes,
        extrusionColor: "#00ff00",
      })

    );

    preview?.resize();

    window.addEventListener('resize', resizePreview);

    return () => {
      window.removeEventListener('resize', resizePreview);
    };
  }, []);


  return (
    <div className="gcode-preview" style={{width: '100%'}}>
      <canvas ref={canvasRef} width="auto" height="auto" style={{width: '100%'}}></canvas>

      <div>
        <div>topLayerColor: {topLayerColor}</div>
        <div>lastSegmentColor: {lastSegmentColor}</div>
        <div>startLayer: {startLayer}</div>
        <div>endLayer: {endLayer}</div>
        <div>lineWidth: {lineWidth}</div>
      </div>
    </div>
  );
}

export default forwardRef(GCodePreviewUI);
