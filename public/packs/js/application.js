(self["webpackChunktentacles"] = self["webpackChunktentacles"] || []).push([["application"],{

/***/ "./app/ui/Foundation/App/App.tsx":
/*!***************************************!*\
  !*** ./app/ui/Foundation/App/App.tsx ***!
  \***************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! react */ "./node_modules/react/index.js");
/* harmony import */ var antd__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! antd */ "./node_modules/antd/es/layout/index.js");
/* harmony import */ var antd__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! antd */ "./node_modules/antd/es/menu/index.js");
/* harmony import */ var antd__WEBPACK_IMPORTED_MODULE_13__ = __webpack_require__(/*! antd */ "./node_modules/antd/es/breadcrumb/index.js");
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! @ant-design/icons */ "./node_modules/@ant-design/icons/es/icons/PieChartOutlined.js");
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_8___default = /*#__PURE__*/__webpack_require__.n(_ant_design_icons__WEBPACK_IMPORTED_MODULE_8__);
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! @ant-design/icons */ "./node_modules/@ant-design/icons/es/icons/DesktopOutlined.js");
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_9___default = /*#__PURE__*/__webpack_require__.n(_ant_design_icons__WEBPACK_IMPORTED_MODULE_9__);
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! @ant-design/icons */ "./node_modules/@ant-design/icons/es/icons/UserOutlined.js");
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_10___default = /*#__PURE__*/__webpack_require__.n(_ant_design_icons__WEBPACK_IMPORTED_MODULE_10__);
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(/*! @ant-design/icons */ "./node_modules/@ant-design/icons/es/icons/TeamOutlined.js");
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_11___default = /*#__PURE__*/__webpack_require__.n(_ant_design_icons__WEBPACK_IMPORTED_MODULE_11__);
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(/*! @ant-design/icons */ "./node_modules/@ant-design/icons/es/icons/FileOutlined.js");
/* harmony import */ var _ant_design_icons__WEBPACK_IMPORTED_MODULE_12___default = /*#__PURE__*/__webpack_require__.n(_ant_design_icons__WEBPACK_IMPORTED_MODULE_12__);
/* harmony import */ var _App_module_scss__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ./App.module.scss */ "./app/ui/Foundation/App/App.module.scss");
/* harmony import */ var _App_module_scss__WEBPACK_IMPORTED_MODULE_7___default = /*#__PURE__*/__webpack_require__.n(_App_module_scss__WEBPACK_IMPORTED_MODULE_7__);
/* harmony import */ var _apollo_client__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! @apollo/client */ "./node_modules/@apollo/client/core/ApolloClient.js");
/* harmony import */ var _apollo_client__WEBPACK_IMPORTED_MODULE_4___default = /*#__PURE__*/__webpack_require__.n(_apollo_client__WEBPACK_IMPORTED_MODULE_4__);
/* harmony import */ var _apollo_client__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! @apollo/client */ "./node_modules/@apollo/client/index.js");
/* harmony import */ var _apollo_client__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! @apollo/client */ "./node_modules/@apollo/client/cache/index.js");
/* harmony import */ var _apollo_client__WEBPACK_IMPORTED_MODULE_6___default = /*#__PURE__*/__webpack_require__.n(_apollo_client__WEBPACK_IMPORTED_MODULE_6__);
/* harmony import */ var cross_fetch__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! cross-fetch */ "./node_modules/cross-fetch/dist/browser-ponyfill.js");
/* harmony import */ var cross_fetch__WEBPACK_IMPORTED_MODULE_3___default = /*#__PURE__*/__webpack_require__.n(cross_fetch__WEBPACK_IMPORTED_MODULE_3__);
function _slicedToArray(arr, i) { return _arrayWithHoles(arr) || _iterableToArrayLimit(arr, i) || _unsupportedIterableToArray(arr, i) || _nonIterableRest(); }

function _nonIterableRest() { throw new TypeError("Invalid attempt to destructure non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }

function _unsupportedIterableToArray(o, minLen) { if (!o) return; if (typeof o === "string") return _arrayLikeToArray(o, minLen); var n = Object.prototype.toString.call(o).slice(8, -1); if (n === "Object" && o.constructor) n = o.constructor.name; if (n === "Map" || n === "Set") return Array.from(o); if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)) return _arrayLikeToArray(o, minLen); }

function _arrayLikeToArray(arr, len) { if (len == null || len > arr.length) len = arr.length; for (var i = 0, arr2 = new Array(len); i < len; i++) { arr2[i] = arr[i]; } return arr2; }

function _iterableToArrayLimit(arr, i) { var _i = arr == null ? null : typeof Symbol !== "undefined" && arr[Symbol.iterator] || arr["@@iterator"]; if (_i == null) return; var _arr = []; var _n = true; var _d = false; var _s, _e; try { for (_i = _i.call(arr); !(_n = (_s = _i.next()).done); _n = true) { _arr.push(_s.value); if (i && _arr.length === i) break; } } catch (err) { _d = true; _e = err; } finally { try { if (!_n && _i["return"] != null) _i["return"](); } finally { if (_d) throw _e; } } return _arr; }

function _arrayWithHoles(arr) { if (Array.isArray(arr)) return arr; }



 // import './Sections/Printers/PrintersList/PrintersList'

var Header = antd__WEBPACK_IMPORTED_MODULE_1__["default"].Header,
    Content = antd__WEBPACK_IMPORTED_MODULE_1__["default"].Content,
    Footer = antd__WEBPACK_IMPORTED_MODULE_1__["default"].Footer,
    Sider = antd__WEBPACK_IMPORTED_MODULE_1__["default"].Sider;
var SubMenu = antd__WEBPACK_IMPORTED_MODULE_2__["default"].SubMenu; // import 'antd/dist/antd.css';





var client = new _apollo_client__WEBPACK_IMPORTED_MODULE_4__.ApolloClient({
  link: new _apollo_client__WEBPACK_IMPORTED_MODULE_5__.HttpLink({
    uri: '/graphql',
    fetch: (cross_fetch__WEBPACK_IMPORTED_MODULE_3___default())
  }),
  cache: new _apollo_client__WEBPACK_IMPORTED_MODULE_6__.InMemoryCache()
});

function App() {
  var _useState = (0,react__WEBPACK_IMPORTED_MODULE_0__.useState)(false),
      _useState2 = _slicedToArray(_useState, 2),
      collapsed = _useState2[0],
      setCollaped = _useState2[1];

  var onCollapse = function onCollapse() {
    setCollaped(!collapsed);
  };

  return /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(_apollo_client__WEBPACK_IMPORTED_MODULE_5__.ApolloProvider, {
    client: client
  }, /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_1__["default"], {
    style: {
      minHeight: '100vh'
    }
  }, /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(Sider, {
    collapsible: true,
    collapsed: collapsed,
    onCollapse: onCollapse,
    trigger: null
  }, /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement("div", {
    className: (_App_module_scss__WEBPACK_IMPORTED_MODULE_7___default().Logo)
  }), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_2__["default"], {
    theme: "dark",
    defaultSelectedKeys: ['1'],
    mode: "inline"
  }, /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_2__["default"].Item, {
    key: "1",
    icon: /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement((_ant_design_icons__WEBPACK_IMPORTED_MODULE_8___default()), null)
  }, "Dashboard"), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_2__["default"].Item, {
    key: "2",
    icon: /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement((_ant_design_icons__WEBPACK_IMPORTED_MODULE_9___default()), null)
  }, "Option 2"), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(SubMenu, {
    key: "sub1",
    icon: /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement((_ant_design_icons__WEBPACK_IMPORTED_MODULE_10___default()), null),
    title: "User"
  }, /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_2__["default"].Item, {
    key: "3"
  }, "Tom"), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_2__["default"].Item, {
    key: "4"
  }, "Bill"), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_2__["default"].Item, {
    key: "5"
  }, "Alex")), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(SubMenu, {
    key: "sub2",
    icon: /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement((_ant_design_icons__WEBPACK_IMPORTED_MODULE_11___default()), null),
    title: "Team"
  }, /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_2__["default"].Item, {
    key: "6"
  }, "Team 1"), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_2__["default"].Item, {
    key: "8"
  }, "Team 2")), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_2__["default"].Item, {
    key: "9",
    icon: /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement((_ant_design_icons__WEBPACK_IMPORTED_MODULE_12___default()), null)
  }, "Files"))), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_1__["default"], null, /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(Header, {
    className: (_App_module_scss__WEBPACK_IMPORTED_MODULE_7___default().siteLayoutBackground),
    style: {
      padding: 0
    }
  }), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(Content, {
    style: {
      margin: '0 16px'
    }
  }, /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_13__["default"], {
    style: {
      margin: '16px 0'
    }
  }, /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_13__["default"].Item, null, "User"), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(antd__WEBPACK_IMPORTED_MODULE_13__["default"].Item, null, "Bill")), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement("div", {
    className: "site-layout-background",
    style: {
      padding: 24,
      minHeight: 360
    }
  }, "Bill is a cat.")), /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_0__.createElement(Footer, {
    style: {
      textAlign: 'center'
    }
  }, "Tentacles"))));
}

/* harmony default export */ __webpack_exports__["default"] = (App);

/***/ }),

/***/ "./app/ui/packs/application.js":
/*!*************************************!*\
  !*** ./app/ui/packs/application.js ***!
  \*************************************/
/***/ (function(__unused_webpack_module, __webpack_exports__, __webpack_require__) {

"use strict";
__webpack_require__.r(__webpack_exports__);
/* harmony import */ var core_js_stable__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! core-js/stable */ "./node_modules/core-js/stable/index.js");
/* harmony import */ var core_js_stable__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(core_js_stable__WEBPACK_IMPORTED_MODULE_0__);
/* harmony import */ var regenerator_runtime_runtime__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! regenerator-runtime/runtime */ "./node_modules/regenerator-runtime/runtime.js");
/* harmony import */ var regenerator_runtime_runtime__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(regenerator_runtime_runtime__WEBPACK_IMPORTED_MODULE_1__);
/* harmony import */ var react__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! react */ "./node_modules/react/index.js");
/* harmony import */ var react_dom__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! react-dom */ "./node_modules/react-dom/index.js");
/* harmony import */ var _Foundation_App_App__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ../Foundation/App/App */ "./app/ui/Foundation/App/App.tsx");





document.addEventListener("DOMContentLoaded", function () {
  react_dom__WEBPACK_IMPORTED_MODULE_3__.render( /*#__PURE__*/react__WEBPACK_IMPORTED_MODULE_2__.createElement(_Foundation_App_App__WEBPACK_IMPORTED_MODULE_4__["default"], {
    name: "React"
  }), document.body.appendChild(document.createElement("div")));
});

/***/ }),

/***/ "./app/ui/Foundation/App/App.module.scss":
/*!***********************************************!*\
  !*** ./app/ui/Foundation/App/App.module.scss ***!
  \***********************************************/
/***/ (function() {

throw new Error("Module build failed (from ./node_modules/mini-css-extract-plugin/dist/loader.js):\nHookWebpackError: Module build failed: Error: ENOENT: no such file or directory, open '/Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/runtime/sourceMaps.js'\n    at tryRunOrWebpackError (/Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/HookWebpackError.js:88:9)\n    at __webpack_require_module__ (/Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/Compilation.js:5049:12)\n    at __webpack_require__ (/Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/Compilation.js:5006:18)\n    at Module.<anonymous> (/Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/cjs.js??ruleSet[1].rules[4].use[1]!/Users/sophiedeziel/dev/Tentacles/node_modules/postcss-loader/dist/cjs.js??ruleSet[1].rules[4].use[2]!/Users/sophiedeziel/dev/Tentacles/node_modules/sass-loader/dist/cjs.js??ruleSet[1].rules[4].use[3]!/Users/sophiedeziel/dev/Tentacles/app/ui/Foundation/App/App.module.scss:2:109)\n    at /Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/javascript/JavascriptModulesPlugin.js:441:11\n    at Hook.eval [as call] (eval at create (/Users/sophiedeziel/dev/Tentacles/node_modules/tapable/lib/HookCodeFactory.js:19:10), <anonymous>:7:1)\n    at /Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/Compilation.js:5051:39\n    at tryRunOrWebpackError (/Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/HookWebpackError.js:83:7)\n    at __webpack_require_module__ (/Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/Compilation.js:5049:12)\n    at __webpack_require__ (/Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/Compilation.js:5006:18)\n-- inner error --\nError: Module build failed: Error: ENOENT: no such file or directory, open '/Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/runtime/sourceMaps.js'\n    at Object.<anonymous> (/Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/runtime/sourceMaps.js:1:7)\n    at /Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/javascript/JavascriptModulesPlugin.js:441:11\n    at Hook.eval [as call] (eval at create (/Users/sophiedeziel/dev/Tentacles/node_modules/tapable/lib/HookCodeFactory.js:19:10), <anonymous>:7:1)\n    at /Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/Compilation.js:5051:39\n    at tryRunOrWebpackError (/Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/HookWebpackError.js:83:7)\n    at __webpack_require_module__ (/Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/Compilation.js:5049:12)\n    at __webpack_require__ (/Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/Compilation.js:5006:18)\n    at Module.<anonymous> (/Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/cjs.js??ruleSet[1].rules[4].use[1]!/Users/sophiedeziel/dev/Tentacles/node_modules/postcss-loader/dist/cjs.js??ruleSet[1].rules[4].use[2]!/Users/sophiedeziel/dev/Tentacles/node_modules/sass-loader/dist/cjs.js??ruleSet[1].rules[4].use[3]!/Users/sophiedeziel/dev/Tentacles/app/ui/Foundation/App/App.module.scss:2:109)\n    at /Users/sophiedeziel/dev/Tentacles/node_modules/webpack/lib/javascript/JavascriptModulesPlugin.js:441:11\n    at Hook.eval [as call] (eval at create (/Users/sophiedeziel/dev/Tentacles/node_modules/tapable/lib/HookCodeFactory.js:19:10), <anonymous>:7:1)\n\nGenerated code for /Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/runtime/sourceMaps.js\n1 | throw new Error(\"Module build failed: Error: ENOENT: no such file or directory, open '/Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/runtime/sourceMaps.js'\");\n\nGenerated code for /Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/cjs.js??ruleSet[1].rules[4].use[1]!/Users/sophiedeziel/dev/Tentacles/node_modules/postcss-loader/dist/cjs.js??ruleSet[1].rules[4].use[2]!/Users/sophiedeziel/dev/Tentacles/node_modules/sass-loader/dist/cjs.js??ruleSet[1].rules[4].use[3]!/Users/sophiedeziel/dev/Tentacles/app/ui/Foundation/App/App.module.scss\n 1 | __webpack_require__.r(__webpack_exports__);\n 2 | /* harmony import */ var _node_modules_css_loader_dist_runtime_sourceMaps_js__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../../../../node_modules/css-loader/dist/runtime/sourceMaps.js */ \"/Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/runtime/sourceMaps.js\");\n 3 | /* harmony import */ var _node_modules_css_loader_dist_runtime_sourceMaps_js__WEBPACK_IMPORTED_MODULE_0___default = /*#__PURE__*/__webpack_require__.n(_node_modules_css_loader_dist_runtime_sourceMaps_js__WEBPACK_IMPORTED_MODULE_0__);\n 4 | /* harmony import */ var _node_modules_css_loader_dist_runtime_api_js__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ../../../../node_modules/css-loader/dist/runtime/api.js */ \"/Users/sophiedeziel/dev/Tentacles/node_modules/css-loader/dist/runtime/api.js\");\n 5 | /* harmony import */ var _node_modules_css_loader_dist_runtime_api_js__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_node_modules_css_loader_dist_runtime_api_js__WEBPACK_IMPORTED_MODULE_1__);\n 6 | // Imports\n 7 | \n 8 | \n 9 | var ___CSS_LOADER_EXPORT___ = _node_modules_css_loader_dist_runtime_api_js__WEBPACK_IMPORTED_MODULE_1___default()((_node_modules_css_loader_dist_runtime_sourceMaps_js__WEBPACK_IMPORTED_MODULE_0___default()));\n10 | // Module\n11 | ___CSS_LOADER_EXPORT___.push([module.id, \".INfdsmk2V7N4FG9Zlos4 {\\n  height: 32px;\\n  margin: 16px;\\n  background: rgba(255, 255, 255, 0.3); }\\n\\n.WwYifoicZIBcCcZt7VUr {\\n  background: #fff; }\\n\", \"\",{\"version\":3,\"sources\":[\"webpack://./app/ui/Foundation/App/App.module.scss\"],\"names\":[],\"mappings\":\"AAAA;EACE,YAAY;EACZ,YAAY;EACZ,oCAAoC,EAAA;;AAGtC;EACE,gBAAgB,EAAA\",\"sourcesContent\":[\".Logo {\\n  height: 32px;\\n  margin: 16px;\\n  background: rgba(255, 255, 255, 0.3);\\n}\\n\\n.siteLayoutBackground {\\n  background: #fff;\\n}\"],\"sourceRoot\":\"\"}]);\n12 | // Exports\n13 | ___CSS_LOADER_EXPORT___.locals = {\n14 | \t\"Logo\": \"INfdsmk2V7N4FG9Zlos4\",\n15 | \t\"siteLayoutBackground\": \"WwYifoicZIBcCcZt7VUr\"\n16 | };\n17 | /* harmony default export */ __webpack_exports__[\"default\"] = (___CSS_LOADER_EXPORT___);\n18 | ");

/***/ })

},
/******/ function(__webpack_require__) { // webpackRuntimeModules
/******/ var __webpack_exec__ = function(moduleId) { return __webpack_require__(__webpack_require__.s = moduleId); }
/******/ __webpack_require__.O(0, ["vendors-node_modules_ant-design_icons_es_icons_DesktopOutlined_js-node_modules_ant-design_ico-9e86dc"], function() { return __webpack_exec__("./app/ui/packs/application.js"); });
/******/ var __webpack_exports__ = __webpack_require__.O();
/******/ }
]);
//# sourceMappingURL=application.js.map