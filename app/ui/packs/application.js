import 'core-js/stable'
import 'regenerator-runtime/runtime'

import React from "react";
import ReactDOM from 'react-dom';

import App from "../foundation/App/App";

document.addEventListener("DOMContentLoaded", () => {
  ReactDOM.render(
    <App name="React" />,
    document.body.appendChild(document.createElement("div"))
  );
});