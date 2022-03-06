import React from 'react'
import ReactDOM from 'react-dom'

const Hello = props => (
  React.createElement('div', null, `Hello ${props.name}`)
)

Hello.defaultProps = {
  name: 'David'
}

document.addEventListener('DOMContentLoaded', () => {
  ReactDOM.render(
    React.createElement(Hello, {name: 'Rails 7'}, null),
    document.getElementById('app'),
  )
})