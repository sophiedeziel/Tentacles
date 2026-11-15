import React from 'react'
import PropTypes from 'prop-types'
import TentacleMark from './TentacleMark'

import * as classes from './Wordmark.module.less'

// The tentacle mark and "Tentacles", for the dark navigation.
// Collapsed, only the mark shows and it carries the name for screen readers.
function Wordmark ({ collapsed = false }) {
  return (
    <div className={classes.wordmark}>
      <TentacleMark title={collapsed ? 'Tentacles' : undefined} />
      {!collapsed && <span className={classes.name}>Tentacles</span>}
    </div>
  )
}

Wordmark.propTypes = {
  collapsed: PropTypes.bool
}

export default Wordmark
