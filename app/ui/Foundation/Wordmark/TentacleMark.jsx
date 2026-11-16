import React from 'react'
import PropTypes from 'prop-types'
import { BRAND_PURPLE, BRAND_PURPLE_LIGHT, BRAND_PURPLE_PALE } from '../theme'
import { SUCKERS, TENTACLE_PATH } from '../tentacle'

// The tentacle mark, reversed for the dark navigation.
// The viewBox crops the 64×64 grid to the mark's 1:2 column so it sits flush against the word.
function TentacleMark ({ height = 40, title }) {
  return (
    <svg
      viewBox="16 0 32 64"
      width={height / 2}
      height={height}
      focusable="false"
      {...(title ? { role: 'img', 'aria-label': title } : { 'aria-hidden': true })}
    >
      <path fill={BRAND_PURPLE_LIGHT} d={TENTACLE_PATH} />
      {SUCKERS.map(([cx, cy, outer, inner]) => (
        <g key={`${cx},${cy}`}>
          <circle cx={cx} cy={cy} r={outer} fill={BRAND_PURPLE_PALE} />
          <circle cx={cx} cy={cy} r={inner} fill={BRAND_PURPLE} />
        </g>
      ))}
    </svg>
  )
}

TentacleMark.propTypes = {
  height: PropTypes.number,
  title: PropTypes.string
}

export default TentacleMark
