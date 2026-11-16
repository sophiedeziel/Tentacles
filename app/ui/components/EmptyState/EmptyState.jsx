import React from 'react'
import PropTypes from 'prop-types'
import { Empty } from 'antd'

import { BRAND_PURPLE, BRAND_PURPLE_PALE, STATE_PALETTE } from '../../Foundation/theme'
import { SUCKERS, TENTACLE_PATH } from '../../Foundation/tentacle'
import * as classes from './EmptyState.module.less'

// The 3D printer line icon's frame, gantry and print head (components/icons), without the print on the bed
const PRINTER_PATHS = ['M4 21V3.5', 'M20 21V3.5', 'M4 6.5h16', 'M10.5 6.5h3v2.5h-3z', 'M11.2 9l.8 1.5.8-1.5',
  'M6.5 18h11', 'M2.5 21h19']

// A job card on the same 24 px grid: its outline, the print queue icon's play mark and the next job's line, then an
// empty slot
const CARD_PATH = 'M5 5h14a1.5 1.5 0 0 1 1.5 1.5v12a1.5 1.5 0 0 1-1.5 1.5H5a1.5 1.5 0 0 1-1.5-1.5v-12A1.5 1.5 0 0 1 5 5z'
const CARD_PATHS = ['M6.5 8v3l2.5-1.5z', 'M11 9.5h6.5']
const SLOT_PATH = 'M7 13h10a.5.5 0 0 1 .5.5v3.5a.5.5 0 0 1-.5.5H7a.5.5 0 0 1-.5-.5v-3.5a.5.5 0 0 1 .5-.5z'

// The G-code file line icon (components/icons): a sheet with a folded corner and a G on it
const SHEET_PATH = 'M14 2.5H7a2 2 0 0 0-2 2v15a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-12z'
const FILE_PATHS = ['M14 2.5v5h5', 'M14.3 12.9a3 3 0 1 0 .7 2.1h-2.5']

// Line art drawn on the line icons' 24 px grid, three times bigger, with its top left corner at x, y
function LineArt ({ x, y, color = BRAND_PURPLE, fill = 'none', paths, dashed = false }) {
  return (
    <g transform={`translate(${x} ${y}) scale(3)`} fill={fill} stroke={color} strokeWidth="0.85"
      strokeLinecap="round" strokeLinejoin="round" strokeDasharray={dashed ? '1.4 1' : undefined}>
      {paths.map((d) => <path key={d} d={d} />)}
    </g>
  )
}

// The brand tentacle (on its 64 px grid), scaled down with its top left corner at x, y
function Tentacle ({ x, y, scale }) {
  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`}>
      <path d={TENTACLE_PATH} fill={BRAND_PURPLE} />
      {SUCKERS.map(([cx, cy, outer, inner]) => (
        <g key={`${cx},${cy}`}>
          <circle cx={cx} cy={cy} r={outer} fill="#b37feb" />
          <circle cx={cx} cy={cy} r={inner} fill="#531dab" />
        </g>
      ))}
    </g>
  )
}

// Every illustration: a soft circle, with line art and the tentacle drawn over it
function Scene ({ children }) {
  return (
    <svg viewBox="0 0 160 120" width="160" height="120" aria-hidden="true">
      <circle cx="80" cy="62" r="52" fill={STATE_PALETTE.PRINTING.tint} />
      {children}
    </svg>
  )
}

// An empty 3D printer, with a small tentacle curled up on its bed where the print would be
function PrintersIllustration () {
  return (
    <Scene>
      <LineArt x={44} y={26} paths={PRINTER_PATHS} />
      <Tentacle x={68.5} y={60.2} scale={0.33} />
    </Scene>
  )
}

// An empty job card, with a tentacle peeking over its corner from behind it
function QueueIllustration () {
  return (
    <Scene>
      <Tentacle x={80} y={18} scale={0.42} />
      <LineArt x={44} y={24} fill="white" paths={[CARD_PATH]} />
      <LineArt x={44} y={24} paths={CARD_PATHS} />
      <LineArt x={44} y={24} color={BRAND_PURPLE_PALE} dashed paths={[SLOT_PATH]} />
    </Scene>
  )
}

// A G-code file on top of a blank one, with a tentacle peeking over the stack from behind it
function FilesIllustration () {
  return (
    <Scene>
      <Tentacle x={50} y={14} scale={0.42} />
      <LineArt x={50} y={20} fill="white" color={BRAND_PURPLE_PALE} paths={[SHEET_PATH]} />
      <LineArt x={41} y={25} fill="white" paths={[SHEET_PATH]} />
      <LineArt x={41} y={25} paths={FILE_PATHS} />
    </Scene>
  )
}

// One illustration per kind of empty page
const ILLUSTRATIONS = {
  printers: PrintersIllustration,
  queue: QueueIllustration,
  files: FilesIllustration
}

// A page or card with nothing to show yet: an illustration for its `kind`, a title, a description, and what to do
// about it (buttons) as children, side by side
export default function EmptyState ({ kind, title, description, children }) {
  const Illustration = ILLUSTRATIONS[kind]

  return (
    <Empty
      image={<Illustration />}
      styles={{ image: { height: 120, marginBottom: 12 } }}
      description={
        <>
          <div className={classes.title}>{title}</div>
          {description && <div className={classes.description}>{description}</div>}
        </>
      }
    >
      {children && <div className={classes.actions}>{children}</div>}
    </Empty>
  )
}

LineArt.propTypes = {
  x: PropTypes.number.isRequired,
  y: PropTypes.number.isRequired,
  color: PropTypes.string,
  fill: PropTypes.string,
  paths: PropTypes.arrayOf(PropTypes.string).isRequired,
  dashed: PropTypes.bool
}
Tentacle.propTypes = { x: PropTypes.number.isRequired, y: PropTypes.number.isRequired, scale: PropTypes.number.isRequired }
Scene.propTypes = { children: PropTypes.node.isRequired }

EmptyState.propTypes = {
  kind: PropTypes.oneOf(Object.keys(ILLUSTRATIONS)).isRequired,
  title: PropTypes.string.isRequired,
  description: PropTypes.node,
  children: PropTypes.node
}
