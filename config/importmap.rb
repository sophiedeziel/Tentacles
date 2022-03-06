# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "react", to: "https://ga.jspm.io/npm:react@17.0.2/index.js"
pin "react-dom", to: "https://ga.jspm.io/npm:react-dom@17.0.2/index.js"
pin "object-assign", to: "https://ga.jspm.io/npm:object-assign@4.1.1/index.js"
pin "scheduler", to: "https://ga.jspm.io/npm:scheduler@0.20.2/index.js"

pin_all_from "app/javascript/components", under: "components"