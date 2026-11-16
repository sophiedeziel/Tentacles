import React from 'react'
import PropTypes from 'prop-types'

import { BRAND_NIGHT, BRAND_PURPLE_LIGHT } from '../../Foundation/theme'
import { SUCKERS, TENTACLE_PATH } from '../../Foundation/tentacle'

const FILL = { position: 'absolute', inset: 0 }

// Stands in for a webcam stream that can't be shown: a crossed-out camera over a tentacle, a message and an
// optional hint. It fills its parent; the camera scales with the height.
export default function WebcamPlaceholder ({ message, hint }) {
  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', minHeight: 96, background: BRAND_NIGHT, overflow: 'hidden' }}>
      <svg viewBox="0 0 320 180" width="100%" height="100%" preserveAspectRatio="xMaxYMid slice" style={FILL}
        aria-hidden="true">
        <g transform="translate(196 -6) scale(3.2)">
          <path d={TENTACLE_PATH} fill="#1e0a3c" />
          {SUCKERS.map(([cx, cy, outer, inner]) => (
            <g key={`${cx},${cy}`}>
              <circle cx={cx} cy={cy} r={outer} fill="#26104a" />
              <circle cx={cx} cy={cy} r={inner} fill="#1e0a3c" />
            </g>
          ))}
        </g>
      </svg>
      <div style={{
        ...FILL, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '4%',
        padding: 12, textAlign: 'center', color: '#d3adf7', fontSize: 13, lineHeight: '20px'
      }}>
        <svg viewBox="128 50 64 64" style={{ height: 'min(64px, 40%)', flexShrink: 1, minHeight: 24 }} aria-hidden="true">
          <g transform="translate(128 50) scale(2.6667)" fill="none" stroke={BRAND_PURPLE_LIGHT} strokeWidth="1.4"
            strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 3a6.5 6.5 0 1 0 0 13a6.5 6.5 0 1 0 0-13z" />
            <path d="M12 7a2.5 2.5 0 1 0 0 5a2.5 2.5 0 1 0 0-5z" />
            <path d="M12 16v4.5" />
            <path d="M8 21h8" />
          </g>
          <path d="M134 56l52 52" stroke={BRAND_PURPLE_LIGHT} strokeWidth="3.4" strokeLinecap="round" />
          <path d="M134 56l52 52" stroke={BRAND_NIGHT} strokeWidth="1" strokeLinecap="round" transform="translate(2.6 -2.6)" />
        </svg>
        <div>
          <div style={{ fontWeight: 600, color: '#fff' }}>{message}</div>
          {hint && <div>{hint}</div>}
        </div>
      </div>
    </div>
  )
}

WebcamPlaceholder.propTypes = {
  message: PropTypes.string.isRequired,
  hint: PropTypes.string
}
