module.exports =
/******/ (function(modules) { // webpackBootstrap
/******/ 	// The module cache
/******/ 	var installedModules = {};
/******/
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/
/******/ 		// Check if module is in cache
/******/ 		if(installedModules[moduleId]) {
/******/ 			return installedModules[moduleId].exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = installedModules[moduleId] = {
/******/ 			i: moduleId,
/******/ 			l: false,
/******/ 			exports: {}
/******/ 		};
/******/
/******/ 		// Execute the module function
/******/ 		modules[moduleId].call(module.exports, module, module.exports, __webpack_require__);
/******/
/******/ 		// Flag the module as loaded
/******/ 		module.l = true;
/******/
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/
/******/
/******/ 	// expose the modules object (__webpack_modules__)
/******/ 	__webpack_require__.m = modules;
/******/
/******/ 	// expose the module cache
/******/ 	__webpack_require__.c = installedModules;
/******/
/******/ 	// define getter function for harmony exports
/******/ 	__webpack_require__.d = function(exports, name, getter) {
/******/ 		if(!__webpack_require__.o(exports, name)) {
/******/ 			Object.defineProperty(exports, name, { enumerable: true, get: getter });
/******/ 		}
/******/ 	};
/******/
/******/ 	// define __esModule on exports
/******/ 	__webpack_require__.r = function(exports) {
/******/ 		if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 			Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 		}
/******/ 		Object.defineProperty(exports, '__esModule', { value: true });
/******/ 	};
/******/
/******/ 	// create a fake namespace object
/******/ 	// mode & 1: value is a module id, require it
/******/ 	// mode & 2: merge all properties of value into the ns
/******/ 	// mode & 4: return value when already ns object
/******/ 	// mode & 8|1: behave like require
/******/ 	__webpack_require__.t = function(value, mode) {
/******/ 		if(mode & 1) value = __webpack_require__(value);
/******/ 		if(mode & 8) return value;
/******/ 		if((mode & 4) && typeof value === 'object' && value && value.__esModule) return value;
/******/ 		var ns = Object.create(null);
/******/ 		__webpack_require__.r(ns);
/******/ 		Object.defineProperty(ns, 'default', { enumerable: true, value: value });
/******/ 		if(mode & 2 && typeof value != 'string') for(var key in value) __webpack_require__.d(ns, key, function(key) { return value[key]; }.bind(null, key));
/******/ 		return ns;
/******/ 	};
/******/
/******/ 	// getDefaultExport function for compatibility with non-harmony modules
/******/ 	__webpack_require__.n = function(module) {
/******/ 		var getter = module && module.__esModule ?
/******/ 			function getDefault() { return module['default']; } :
/******/ 			function getModuleExports() { return module; };
/******/ 		__webpack_require__.d(getter, 'a', getter);
/******/ 		return getter;
/******/ 	};
/******/
/******/ 	// Object.prototype.hasOwnProperty.call
/******/ 	__webpack_require__.o = function(object, property) { return Object.prototype.hasOwnProperty.call(object, property); };
/******/
/******/ 	// __webpack_public_path__
/******/ 	__webpack_require__.p = "http://localhost:8080/webpack/assets/";
/******/
/******/
/******/ 	// Load entry module and return exports
/******/ 	return __webpack_require__(__webpack_require__.s = 0);
/******/ })
/************************************************************************/
/******/ ({

/***/ "./app/ui/index.tsx":
/*!**************************!*\
  !*** ./app/ui/index.tsx ***!
  \**************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _react = _interopRequireDefault(__webpack_require__(/*! react */ "react"));

var _jsxFileName = "/Users/sophiedeziel/dev/Tentacles/app/ui/index.tsx";

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function App() {
  return /*#__PURE__*/_react.default.createElement("div", {
    __self: this,
    __source: {
      fileName: _jsxFileName,
      lineNumber: 4,
      columnNumber: 10
    }
  }, "Hello Quilt");
}

var _default = App;
exports.default = _default;

/***/ }),

/***/ "./app/ui/server.js":
/*!**************************!*\
  !*** ./app/ui/server.js ***!
  \**************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _react = _interopRequireDefault(__webpack_require__(/*! react */ "react"));

var _reactServer = __webpack_require__(/*! @shopify/react-server */ "./node_modules/@shopify/react-server/index.esnext");

var _index = _interopRequireDefault(__webpack_require__(/*! index */ "./app/ui/index.tsx"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

// Generated by @shopify/react-server/webpack-plugin
process.on('uncaughtException', logError);
process.on('unhandledRejection', logError);

function logError(error) {
  const errorLog = `${error.stack || error.message || 'No stack trace was present'}`;
  console.log(`React Server failed to start.
${errorLog}`);
  process.exit(1);
}

const render = ctx => {
  return /*#__PURE__*/_react.default.createElement(_index.default, {
    url: ctx.request.URL,
    data: ctx.state.quiltData
  });
};

const app = (0, _reactServer.createServer)({
  port: undefined,
  ip: undefined,
  assetPrefix: "http://localhost:8080/webpack/assets/",
  proxy: true,
  render
});
var _default = app;
exports.default = _default;

/***/ }),

/***/ "./node_modules/@shopify/async/build/esnext/index.esnext":
/*!***************************************************************!*\
  !*** ./node_modules/@shopify/async/build/esnext/index.esnext ***!
  \***************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
Object.defineProperty(exports, "DeferTiming", {
  enumerable: true,
  get: function () {
    return _types.DeferTiming;
  }
});
Object.defineProperty(exports, "createResolver", {
  enumerable: true,
  get: function () {
    return _resolver.createResolver;
  }
});

var _types = __webpack_require__(/*! ./types.esnext */ "./node_modules/@shopify/async/build/esnext/types.esnext");

var _resolver = __webpack_require__(/*! ./resolver.esnext */ "./node_modules/@shopify/async/build/esnext/resolver.esnext");

/***/ }),

/***/ "./node_modules/@shopify/async/build/esnext/resolver.esnext":
/*!******************************************************************!*\
  !*** ./node_modules/@shopify/async/build/esnext/resolver.esnext ***!
  \******************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";
/* WEBPACK VAR INJECTION */(function(module) {

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.createResolver = createResolver;

function createResolver({
  id,
  load
}) {
  let resolved = null;
  let resolvePromise = null;
  let hasTriedSyncResolve = false;
  const resolvedId = id && id();
  return {
    get id() {
      return resolvedId;
    },

    get resolved() {
      if (resolved == null && !hasTriedSyncResolve) {
        hasTriedSyncResolve = true;
        resolved = resolvedId ? trySynchronousResolve(resolvedId) : null;
      }

      return resolved;
    },

    resolve: async () => {
      resolvePromise = resolvePromise || resolve(load);
      resolved = await resolvePromise;
      return resolved;
    }
  };
}

async function resolve(load) {
  const resolved = await load();
  return normalize(resolved);
}

function normalize(module) {
  if (module == null) {
    return null;
  }

  const value = typeof module === 'object' && 'default' in module ? module.default : module;
  return value == null ? null : value;
} // Webpack does not like seeing an explicit require(someVariable) in code
// because that is a dynamic require that it can’t resolve. This code
// obfuscates `require()` for the purpose of fooling Webpack, which is fine
// because we only want to use the `require()` in cases where Webpack
// is not the module bundler.
//
// If we ever reference `require` directly, Webpack complains. So, we first
// check global["require"], which works in Node. However, this doesn’t work
// in Jest when the test is set to simulate a browser, as global in that case
// in a Window object. There, we can only rely on module.require, which is
// actually supposed to be something different but in Jest is the same as
// the global require function.


const requireKey = 'require';
const nodeRequire = typeof global === 'object' && typeof global[requireKey] === 'function' && global[requireKey] ||  true && typeof module[requireKey] === 'function' && module[requireKey] || undefined; // If we have an ID, we try to first use Webpack’s internal stuff
// to resolve the module. If those don’t exist, we know we aren’t
// inside of a Webpack bundle, so we try to use Node’s native resolution
// (which will work in environments like Jest’s test runner).

function tryRequire(id) {
  if ( true && __webpack_require__.m[id]) {
    try {
      return normalize(__webpack_require__(id));
    } catch {// Just ignore failures
    }
  } else if (typeof nodeRequire === 'function') {
    try {
      return normalize(nodeRequire(id));
    } catch {// Just ignore failures
    }
  }

  return undefined;
}

function trySynchronousResolve(id) {
  return tryRequire(id) || null;
}
/* WEBPACK VAR INJECTION */}.call(this, __webpack_require__(/*! ./../../../../webpack/buildin/module.js */ "./node_modules/webpack/buildin/module.js")(module)))

/***/ }),

/***/ "./node_modules/@shopify/async/build/esnext/types.esnext":
/*!***************************************************************!*\
  !*** ./node_modules/@shopify/async/build/esnext/types.esnext ***!
  \***************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.DeferTiming = void 0;
let DeferTiming;
exports.DeferTiming = DeferTiming;

(function (DeferTiming) {
  DeferTiming[DeferTiming["Mount"] = 0] = "Mount";
  DeferTiming[DeferTiming["Idle"] = 1] = "Idle";
  DeferTiming[DeferTiming["InViewport"] = 2] = "InViewport";
})(DeferTiming || (exports.DeferTiming = DeferTiming = {}));

/***/ }),

/***/ "./node_modules/@shopify/async/index.esnext":
/*!**************************************************!*\
  !*** ./node_modules/@shopify/async/index.esnext ***!
  \**************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});

var _index = __webpack_require__(/*! ./build/esnext/index.esnext */ "./node_modules/@shopify/async/build/esnext/index.esnext");

Object.keys(_index).forEach(function (key) {
  if (key === "default" || key === "__esModule") return;
  if (key in exports && exports[key] === _index[key]) return;
  Object.defineProperty(exports, key, {
    enumerable: true,
    get: function () {
      return _index[key];
    }
  });
});

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/EventListener.esnext":
/*!*****************************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/EventListener.esnext ***!
  \*****************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.EventListener = void 0;

var _react = _interopRequireDefault(__webpack_require__(/*! react */ "react"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

// see https://github.com/oliviertassinari/react-event-listener/
class EventListener extends _react.default.PureComponent {
  componentDidMount() {
    this.attachListener();
  }

  componentDidUpdate({
    passive,
    ...detachProps
  }) {
    this.detachListener(detachProps);
    this.attachListener();
  }

  componentWillUnmount() {
    this.detachListener();
  }

  render() {
    return null;
  }

  attachListener() {
    const {
      event,
      handler,
      capture,
      passive
    } = this.props;
    window.addEventListener(event, handler, {
      capture,
      passive
    });
  }

  detachListener(prevProps) {
    const {
      event,
      handler,
      capture
    } = prevProps || this.props;
    window.removeEventListener(event, handler, capture);
  }

}

exports.EventListener = EventListener;

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/PrefetchRoute.esnext":
/*!*****************************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/PrefetchRoute.esnext ***!
  \*****************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.PrefetchRoute = PrefetchRoute;

var _react = _interopRequireDefault(__webpack_require__(/*! react */ "react"));

var _prefetch = __webpack_require__(/*! ./context/prefetch.esnext */ "./node_modules/@shopify/react-async/build/esnext/context/prefetch.esnext");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

class ConnectedPrefetchRoute extends _react.default.Component {
  constructor(...args) {
    super(...args);
    this.unregister = void 0;
  }

  componentDidMount() {
    const {
      manager,
      path,
      render
    } = this.props;
    this.unregister = manager.register({
      path,
      render
    });
  }

  componentWillUnmount() {
    if (this.unregister) {
      this.unregister();
    }
  }

  render() {
    return null;
  }

}

function PrefetchRoute(props) {
  return /*#__PURE__*/_react.default.createElement(_prefetch.PrefetchContext.Consumer, null, manager => /*#__PURE__*/_react.default.createElement(ConnectedPrefetchRoute, Object.assign({
    manager: manager
  }, props)));
}

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/Prefetcher.esnext":
/*!**************************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/Prefetcher.esnext ***!
  \**************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.INTENTION_DELAY_MS = void 0;
exports.Prefetcher = Prefetcher;

var _react = _interopRequireDefault(__webpack_require__(/*! react */ "react"));

var _prefetch = __webpack_require__(/*! ./context/prefetch.esnext */ "./node_modules/@shopify/react-async/build/esnext/context/prefetch.esnext");

var _EventListener = __webpack_require__(/*! ./EventListener.esnext */ "./node_modules/@shopify/react-async/build/esnext/EventListener.esnext");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

const INTENTION_DELAY_MS = 150;
exports.INTENTION_DELAY_MS = INTENTION_DELAY_MS;

class ConnectedPrefetcher extends _react.default.PureComponent {
  constructor(...args) {
    super(...args);
    this.state = {};
    this.timeout = void 0;
    this.timeoutUrl = void 0;
    this.prefetchAgressively = shouldPrefetchAggressively();

    this.handlePressStart = ({
      target
    }) => {
      this.clearTimeout();

      if (target == null) {
        return;
      }

      const url = closestUrlFromNode(target);

      if (url != null) {
        this.setState({
          url
        });
      }
    };

    this.handlePointerLeave = ({
      target,
      relatedTarget
    }) => {
      const {
        url
      } = this.state;
      const {
        timeout,
        timeoutUrl
      } = this;

      if (target == null) {
        if (timeout) {
          this.clearTimeout();
        }

        return;
      }

      if (url == null && timeout == null) {
        return;
      }

      const closestUrl = closestUrlFromNode(target);
      const relatedUrl = relatedTarget && closestUrlFromNode(relatedTarget);

      if (timeout != null && urlsEqual(closestUrl, timeoutUrl) && !urlsEqual(relatedUrl, timeoutUrl)) {
        this.clearTimeout();
      }

      if (urlsEqual(closestUrl, url) && !urlsEqual(relatedUrl, url)) {
        this.setState({
          url: undefined
        });
      }
    };

    this.handlePointerEnter = ({
      target
    }) => {
      if (target == null) {
        return;
      }

      const {
        timeoutUrl,
        timeout
      } = this;
      const url = closestUrlFromNode(target);

      if (url == null) {
        return;
      }

      if (timeout) {
        if (urlsEqual(url, timeoutUrl)) {
          return;
        } else {
          this.clearTimeout();
        }
      }

      this.timeoutUrl = url;
      this.timeout = setTimeout(() => {
        this.clearTimeout();
        this.setState({
          url
        });
      }, INTENTION_DELAY_MS);
    };
  }

  render() {
    const {
      url
    } = this.state;
    const {
      manager
    } = this.props;
    const preloadMarkup = url ? /*#__PURE__*/_react.default.createElement("div", {
      style: {
        visibility: 'hidden'
      }
    }, findMatches(manager.registered, url).map(({
      render,
      path
    }, index) => {
      // eslint-disable-next-line react/no-array-index-key
      return /*#__PURE__*/_react.default.createElement("div", {
        key: `${path}${index}`
      }, render(url));
    })) : null;
    const expensiveListeners = this.prefetchAgressively ? /*#__PURE__*/_react.default.createElement(_react.default.Fragment, null, /*#__PURE__*/_react.default.createElement(_EventListener.EventListener, {
      passive: true,
      event: "mouseover",
      handler: this.handlePointerEnter
    }), /*#__PURE__*/_react.default.createElement(_EventListener.EventListener, {
      passive: true,
      event: "focusin",
      handler: this.handlePointerEnter
    }), /*#__PURE__*/_react.default.createElement(_EventListener.EventListener, {
      passive: true,
      event: "mouseout",
      handler: this.handlePointerLeave
    }), /*#__PURE__*/_react.default.createElement(_EventListener.EventListener, {
      passive: true,
      event: "focusout",
      handler: this.handlePointerLeave
    })) : null;
    return /*#__PURE__*/_react.default.createElement(_react.default.Fragment, null, /*#__PURE__*/_react.default.createElement(_EventListener.EventListener, {
      passive: true,
      event: "mousedown",
      handler: this.handlePressStart
    }), /*#__PURE__*/_react.default.createElement(_EventListener.EventListener, {
      passive: true,
      event: "touchstart",
      handler: this.handlePressStart
    }), expensiveListeners, preloadMarkup);
  }

  clearTimeout() {
    if (this.timeout != null) {
      clearTimeout(this.timeout);
      this.timeout = undefined;
      this.timeoutUrl = undefined;
    }
  }

}

function Prefetcher(props) {
  return /*#__PURE__*/_react.default.createElement(_prefetch.PrefetchContext.Consumer, null, manager => /*#__PURE__*/_react.default.createElement(ConnectedPrefetcher, Object.assign({}, props, {
    manager: manager
  })));
}

function shouldPrefetchAggressively() {
  return typeof navigator === 'undefined' || !('connection' in navigator) || !navigator.connection.saveData;
}

function urlsEqual(first, second) {
  return first == null && first === second || first != null && second != null && first.href === second.href;
}

function findMatches(records, url) {
  return [...records].filter(({
    path: match
  }) => matches(url, match));
}

function matches(url, matcher) {
  return typeof matcher === 'string' ? matcher === url.pathname : matcher.test(url.pathname);
}

function closestUrlFromNode(element) {
  if (!(element instanceof HTMLElement)) {
    return undefined;
  } // data-href is a hack for resource list doing the <a> as a sibling


  const closestUrl = element.closest('[href], [data-href]');

  if (closestUrl == null || !(closestUrl instanceof HTMLElement)) {
    return undefined;
  }

  const url = closestUrl.getAttribute('href') || closestUrl.getAttribute('data-href');

  try {
    return url ? new URL(url, window.location.href) : undefined;
  } catch (error) {
    return undefined;
  }
}

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/component.esnext":
/*!*************************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/component.esnext ***!
  \*************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.createAsyncComponent = createAsyncComponent;

var _react = _interopRequireWildcard(__webpack_require__(/*! react */ "react"));

var _async = __webpack_require__(/*! @shopify/async */ "./node_modules/@shopify/async/index.esnext");

var _reactIntersectionObserver = __webpack_require__(/*! @shopify/react-intersection-observer */ "@shopify/react-intersection-observer");

var _reactIdle = __webpack_require__(/*! @shopify/react-idle */ "@shopify/react-idle");

var _reactHydrate = __webpack_require__(/*! @shopify/react-hydrate */ "@shopify/react-hydrate");

var _hooks = __webpack_require__(/*! ./hooks.esnext */ "./node_modules/@shopify/react-async/build/esnext/hooks.esnext");

var _types = __webpack_require__(/*! ./types.esnext */ "./node_modules/@shopify/react-async/build/esnext/types.esnext");

function _getRequireWildcardCache(nodeInterop) { if (typeof WeakMap !== "function") return null; var cacheBabelInterop = new WeakMap(); var cacheNodeInterop = new WeakMap(); return (_getRequireWildcardCache = function (nodeInterop) { return nodeInterop ? cacheNodeInterop : cacheBabelInterop; })(nodeInterop); }

function _interopRequireWildcard(obj, nodeInterop) { if (!nodeInterop && obj && obj.__esModule) { return obj; } if (obj === null || typeof obj !== "object" && typeof obj !== "function") { return { default: obj }; } var cache = _getRequireWildcardCache(nodeInterop); if (cache && cache.has(obj)) { return cache.get(obj); } var newObj = {}; var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor; for (var key in obj) { if (key !== "default" && Object.prototype.hasOwnProperty.call(obj, key)) { var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null; if (desc && (desc.get || desc.set)) { Object.defineProperty(newObj, key, desc); } else { newObj[key] = obj[key]; } } } newObj.default = obj; if (cache) { cache.set(obj, newObj); } return newObj; }

function createAsyncComponent({
  id,
  load,
  defer,
  deferHydration,
  displayName,
  renderLoading = noopRender,
  renderError = defaultRenderError,
  usePreload: useCustomPreload = noopUse,
  usePrefetch: useCustomPrefetch = noopUse,
  useKeepFresh: useCustomKeepFresh = noopUse
}) {
  const resolver = (0, _async.createResolver)({
    id,
    load
  });
  const componentName = displayName || displayNameFromId(resolver.id);
  const deferred = defer != null;
  const progressivelyHydrated = deferHydration != null;
  const scriptTiming = deferred || progressivelyHydrated ? _types.AssetTiming.CurrentPage : _types.AssetTiming.Immediate;
  const stylesTiming = deferred ? _types.AssetTiming.CurrentPage : _types.AssetTiming.Immediate;

  function Async(props) {
    const {
      resolved: Component,
      load,
      loading,
      error
    } = (0, _hooks.useAsync)(resolver, {
      scripts: scriptTiming,
      styles: stylesTiming,
      immediate: !deferred
    });
    const {
      current: startedHydrated
    } = (0, _react.useRef)((0, _reactHydrate.useHydrationManager)().hydrated);

    if (error) {
      return renderError(error);
    }

    let loadingMarkup = null;

    if (progressivelyHydrated && !startedHydrated) {
      loadingMarkup = /*#__PURE__*/_react.default.createElement(Loader, {
        defer: deferHydration,
        load: load,
        props: props
      });
    } else if (loading) {
      loadingMarkup = /*#__PURE__*/_react.default.createElement(Loader, {
        defer: defer,
        load: load,
        props: props
      });
    }

    let contentMarkup = null;
    const rendered = Component ? /*#__PURE__*/_react.default.createElement(Component, props) : null;

    if (progressivelyHydrated && !startedHydrated) {
      contentMarkup = rendered ? /*#__PURE__*/_react.default.createElement(_reactHydrate.Hydrator, {
        id: resolver.id
      }, rendered) : /*#__PURE__*/_react.default.createElement(_reactHydrate.Hydrator, {
        id: resolver.id
      });
    } else if (loading) {
      contentMarkup = renderLoading(props);
    } else {
      contentMarkup = rendered;
    }

    return /*#__PURE__*/_react.default.createElement(_react.default.Fragment, null, contentMarkup, loadingMarkup);
  }

  Async.displayName = `Async(${componentName})`;

  function usePreload(props) {
    const {
      load
    } = (0, _hooks.useAsync)(resolver, {
      assets: _types.AssetTiming.NextPage
    });
    const customPreload = useCustomPreload(props);
    return (0, _react.useCallback)(() => {
      load();

      if (customPreload) {
        customPreload();
      }
    }, [load, customPreload]);
  }

  function usePrefetch(props) {
    const {
      load
    } = (0, _hooks.useAsync)(resolver, {
      assets: _types.AssetTiming.NextPage
    });
    const customPrefetch = useCustomPrefetch(props);
    return (0, _react.useCallback)(() => {
      load();

      if (customPrefetch) {
        customPrefetch();
      }
    }, [load, customPrefetch]);
  }

  function useKeepFresh(props) {
    const {
      load
    } = (0, _hooks.useAsync)(resolver, {
      assets: _types.AssetTiming.NextPage
    });
    const customKeepFresh = useCustomKeepFresh(props);
    return (0, _react.useCallback)(() => {
      load();

      if (customKeepFresh) {
        customKeepFresh();
      }
    }, [load, customKeepFresh]);
  }

  function Preload(options) {
    (0, _reactIdle.useIdleCallback)(usePreload(options));
    return null;
  }

  Preload.displayName = `Async.Preload(${displayName})`;

  function Prefetch(options) {
    const prefetch = usePrefetch(options);
    (0, _react.useEffect)(() => {
      prefetch();
    }, [prefetch]);
    return null;
  }

  Prefetch.displayName = `Async.Prefetch(${displayName})`;

  function KeepFresh(options) {
    (0, _reactIdle.useIdleCallback)(useKeepFresh(options));
    return null;
  }

  KeepFresh.displayName = `Async.KeepFresh(${displayName})`;
  const FinalComponent = Async;
  Reflect.defineProperty(FinalComponent, 'resolver', {
    value: resolver,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'Preload', {
    value: Preload,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'Prefetch', {
    value: Prefetch,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'KeepFresh', {
    value: KeepFresh,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'usePreload', {
    value: usePreload,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'usePrefetch', {
    value: usePrefetch,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'useKeepFresh', {
    value: useKeepFresh,
    writable: false
  });
  return FinalComponent;
}

function noopUse() {
  return () => {};
}

function noopRender() {
  return null;
}

const DEFAULT_DISPLAY_NAME = 'Component';
const FILENAME_REGEX = /([^/]*)\.\w+$/;

function displayNameFromId(id) {
  if (!id) {
    return DEFAULT_DISPLAY_NAME;
  }

  const match = FILENAME_REGEX.exec(id);
  return match ? match[1] : DEFAULT_DISPLAY_NAME;
}

function defaultRenderError(error) {
  if (error) {
    throw error;
  }

  return null;
}

function Loader({
  defer,
  load,
  props
}) {
  const handleIntersection = (0, _react.useCallback)(({
    isIntersecting = true
  }) => {
    if (isIntersecting) {
      load();
    }
  }, [load]);
  (0, _react.useEffect)(() => {
    if (defer == null || defer === _async.DeferTiming.Mount) {
      load();
    } else if (typeof defer === 'function' && defer(props)) {
      load();
    }
  }, [defer, load, props]);

  if (typeof defer === 'function') {
    return null;
  }

  switch (defer) {
    case _async.DeferTiming.Idle:
      return /*#__PURE__*/_react.default.createElement(_reactIdle.OnIdle, {
        perform: load
      });

    case _async.DeferTiming.InViewport:
      return /*#__PURE__*/_react.default.createElement(_reactIntersectionObserver.IntersectionObserver, {
        threshold: 0,
        onIntersectionChange: handleIntersection
      });

    default:
      return null;
  }
}

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/context/assets.esnext":
/*!******************************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/context/assets.esnext ***!
  \******************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.EFFECT_ID = exports.AsyncAssetManager = exports.AsyncAssetContext = void 0;

var _react = _interopRequireDefault(__webpack_require__(/*! react */ "react"));

var _types = __webpack_require__(/*! ../types.esnext */ "./node_modules/@shopify/react-async/build/esnext/types.esnext");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

const EFFECT_ID = Symbol('react-async');
exports.EFFECT_ID = EFFECT_ID;

class AsyncAssetManager {
  constructor() {
    this.effect = {
      id: EFFECT_ID,
      betweenEachPass: () => {
        this.assets.clear();
      }
    };
    this.assets = new Map();
  }

  used(timing = _types.AssetTiming.Immediate) {
    const timingArray = Array.isArray(timing) ? timing : [timing];
    const assets = [];

    for (const [asset, {
      scripts,
      styles
    }] of this.assets) {
      const scriptsMatch = timingArray.includes(scripts);
      const stylesMatch = timingArray.includes(styles);

      if (stylesMatch || scriptsMatch) {
        assets.push({
          id: asset,
          scripts: scriptsMatch,
          styles: stylesMatch
        });
      }
    }

    return assets;
  }

  markAsUsed(id, timing = _types.AssetTiming.Immediate) {
    const current = this.assets.get(id);
    const scripts = typeof timing === 'object' ? timing.scripts : timing;
    const styles = typeof timing === 'object' ? timing.styles : timing;

    if (current == null) {
      this.assets.set(id, {
        scripts: scripts || _types.AssetTiming.Immediate,
        styles: styles || _types.AssetTiming.Immediate
      });
    } else {
      this.assets.set(id, {
        // the AssetTiming enum has values where the smallest value is
        // the lowest importance load, and the highest value is for assets
        // needed immediately. So, when a new asset comes in that has
        // already been recorded, we can take the maximum value to
        // keep only the highest priority timing for the asset.
        scripts: Math.max(scripts || current.scripts, current.styles),
        styles: Math.max(styles || current.styles, current.styles)
      });
    }
  }

}

exports.AsyncAssetManager = AsyncAssetManager;

const AsyncAssetContext = /*#__PURE__*/_react.default.createContext(null);

exports.AsyncAssetContext = AsyncAssetContext;

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/context/prefetch.esnext":
/*!********************************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/context/prefetch.esnext ***!
  \********************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.PrefetchManager = exports.PrefetchContext = void 0;

var _react = _interopRequireDefault(__webpack_require__(/*! react */ "react"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

class PrefetchManager {
  constructor(registered) {
    this.registered = void 0;
    this.registered = new Set(registered);
  }

  register(registration) {
    this.registered.add(registration);
    return () => this.registered.delete(registration);
  }

}

exports.PrefetchManager = PrefetchManager;

const PrefetchContext = /*#__PURE__*/_react.default.createContext(new PrefetchManager());

exports.PrefetchContext = PrefetchContext;

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/hooks.esnext":
/*!*********************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/hooks.esnext ***!
  \*********************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.useAsync = useAsync;
exports.useAsyncAsset = useAsyncAsset;
exports.useKeepFresh = useKeepFresh;
exports.usePrefetch = usePrefetch;
exports.usePreload = usePreload;

var _react = __webpack_require__(/*! react */ "react");

var _reactEffect = __webpack_require__(/*! @shopify/react-effect */ "@shopify/react-effect");

var _reactHooks = __webpack_require__(/*! @shopify/react-hooks */ "@shopify/react-hooks");

var _assets = __webpack_require__(/*! ./context/assets.esnext */ "./node_modules/@shopify/react-async/build/esnext/context/assets.esnext");

function usePreload(...args) {
  const [preloadable, options = {}] = args;
  return preloadable.usePreload(options);
}

function usePrefetch(...args) {
  const [prefetchable, options = {}] = args;
  return prefetchable.usePrefetch(options);
}

function useKeepFresh(...args) {
  const [keepFreshable, options = {}] = args;
  return keepFreshable.useKeepFresh(options);
}

function useAsync(resolver, {
  assets,
  scripts = assets,
  styles = assets,
  immediate = true
} = {}) {
  const [value, setValue] = (0, _react.useState)(() => immediate || typeof window !== 'undefined' ? resolver.resolved : null);
  const mounted = (0, _reactHooks.useMountedRef)();
  const load = (0, _react.useCallback)(async () => {
    if (value != null) {
      return value;
    }

    try {
      const resolved = await resolver.resolve();

      if (mounted.current) {
        // It's important to use the function form of setValue here.
        // Resolved is going to be a function in most cases, since it's
        // a React component. If you do not set it using the function form,
        // React treats the component as the function that returns state,
        // so it sets state with the result of manually calling the component
        // (so, usually JSX).
        setValue(() => resolved);
      }

      return resolved;
    } catch (error) {
      if (mounted.current) {
        setValue(error);
      }

      return error;
    }
  }, [mounted, resolver, value]);
  const {
    id
  } = resolver;
  useAsyncAsset(id, {
    scripts,
    styles
  });
  return value instanceof Error ? {
    id,
    resolved: null,
    error: value,
    loading: false,
    load
  } : {
    id,
    resolved: value,
    error: null,
    loading: value == null,
    load
  };
}

function useAsyncAsset(id, {
  scripts,
  styles
} = {}) {
  const async = (0, _react.useContext)(_assets.AsyncAssetContext);
  (0, _reactEffect.useServerEffect)(() => {
    if (async && id) {
      async.markAsUsed(id, {
        scripts,
        styles
      });
    }
  }, async === null || async === void 0 ? void 0 : async.effect);
}

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/index.esnext":
/*!*********************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/index.esnext ***!
  \*********************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
Object.defineProperty(exports, "AssetTiming", {
  enumerable: true,
  get: function () {
    return _types.AssetTiming;
  }
});
Object.defineProperty(exports, "AsyncAssetContext", {
  enumerable: true,
  get: function () {
    return _assets.AsyncAssetContext;
  }
});
Object.defineProperty(exports, "AsyncAssetManager", {
  enumerable: true,
  get: function () {
    return _assets.AsyncAssetManager;
  }
});
Object.defineProperty(exports, "DeferTiming", {
  enumerable: true,
  get: function () {
    return _async.DeferTiming;
  }
});
Object.defineProperty(exports, "PrefetchContext", {
  enumerable: true,
  get: function () {
    return _prefetch.PrefetchContext;
  }
});
Object.defineProperty(exports, "PrefetchManager", {
  enumerable: true,
  get: function () {
    return _prefetch.PrefetchManager;
  }
});
Object.defineProperty(exports, "PrefetchRoute", {
  enumerable: true,
  get: function () {
    return _PrefetchRoute.PrefetchRoute;
  }
});
Object.defineProperty(exports, "Prefetcher", {
  enumerable: true,
  get: function () {
    return _Prefetcher.Prefetcher;
  }
});
Object.defineProperty(exports, "createAsyncComponent", {
  enumerable: true,
  get: function () {
    return _component.createAsyncComponent;
  }
});
Object.defineProperty(exports, "createAsyncContext", {
  enumerable: true,
  get: function () {
    return _provider.createAsyncContext;
  }
});
Object.defineProperty(exports, "useAsync", {
  enumerable: true,
  get: function () {
    return _hooks.useAsync;
  }
});
Object.defineProperty(exports, "useAsyncAsset", {
  enumerable: true,
  get: function () {
    return _hooks.useAsyncAsset;
  }
});
Object.defineProperty(exports, "useKeepFresh", {
  enumerable: true,
  get: function () {
    return _hooks.useKeepFresh;
  }
});
Object.defineProperty(exports, "usePrefetch", {
  enumerable: true,
  get: function () {
    return _hooks.usePrefetch;
  }
});
Object.defineProperty(exports, "usePreload", {
  enumerable: true,
  get: function () {
    return _hooks.usePreload;
  }
});

var _async = __webpack_require__(/*! @shopify/async */ "./node_modules/@shopify/async/index.esnext");

var _types = __webpack_require__(/*! ./types.esnext */ "./node_modules/@shopify/react-async/build/esnext/types.esnext");

var _hooks = __webpack_require__(/*! ./hooks.esnext */ "./node_modules/@shopify/react-async/build/esnext/hooks.esnext");

var _Prefetcher = __webpack_require__(/*! ./Prefetcher.esnext */ "./node_modules/@shopify/react-async/build/esnext/Prefetcher.esnext");

var _PrefetchRoute = __webpack_require__(/*! ./PrefetchRoute.esnext */ "./node_modules/@shopify/react-async/build/esnext/PrefetchRoute.esnext");

var _component = __webpack_require__(/*! ./component.esnext */ "./node_modules/@shopify/react-async/build/esnext/component.esnext");

var _provider = __webpack_require__(/*! ./provider.esnext */ "./node_modules/@shopify/react-async/build/esnext/provider.esnext");

var _assets = __webpack_require__(/*! ./context/assets.esnext */ "./node_modules/@shopify/react-async/build/esnext/context/assets.esnext");

var _prefetch = __webpack_require__(/*! ./context/prefetch.esnext */ "./node_modules/@shopify/react-async/build/esnext/context/prefetch.esnext");

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/provider.esnext":
/*!************************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/provider.esnext ***!
  \************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.createAsyncContext = createAsyncContext;

var _react = _interopRequireWildcard(__webpack_require__(/*! react */ "react"));

var _async = __webpack_require__(/*! @shopify/async */ "./node_modules/@shopify/async/index.esnext");

var _reactIdle = __webpack_require__(/*! @shopify/react-idle */ "@shopify/react-idle");

var _hooks = __webpack_require__(/*! ./hooks.esnext */ "./node_modules/@shopify/react-async/build/esnext/hooks.esnext");

var _types = __webpack_require__(/*! ./types.esnext */ "./node_modules/@shopify/react-async/build/esnext/types.esnext");

function _getRequireWildcardCache(nodeInterop) { if (typeof WeakMap !== "function") return null; var cacheBabelInterop = new WeakMap(); var cacheNodeInterop = new WeakMap(); return (_getRequireWildcardCache = function (nodeInterop) { return nodeInterop ? cacheNodeInterop : cacheBabelInterop; })(nodeInterop); }

function _interopRequireWildcard(obj, nodeInterop) { if (!nodeInterop && obj && obj.__esModule) { return obj; } if (obj === null || typeof obj !== "object" && typeof obj !== "function") { return { default: obj }; } var cache = _getRequireWildcardCache(nodeInterop); if (cache && cache.has(obj)) { return cache.get(obj); } var newObj = {}; var hasPropertyDescriptor = Object.defineProperty && Object.getOwnPropertyDescriptor; for (var key in obj) { if (key !== "default" && Object.prototype.hasOwnProperty.call(obj, key)) { var desc = hasPropertyDescriptor ? Object.getOwnPropertyDescriptor(obj, key) : null; if (desc && (desc.get || desc.set)) { Object.defineProperty(newObj, key, desc); } else { newObj[key] = obj[key]; } } } newObj.default = obj; if (cache) { cache.set(obj, newObj); } return newObj; }

function createAsyncContext({
  id,
  load
}) {
  const resolver = (0, _async.createResolver)({
    id,
    load
  });

  const Context = /*#__PURE__*/_react.default.createContext(null); // Just like a "normal" value returned from `createContext`, rendering
  // the value itself is not supported. This component is just a placeholder
  // to provide a more useful error.


  function Root() {
    throw new Error('Do not attempt to render the result of calling `createAsyncContext()` directly. Render its `.Provider` component instead.');
  }

  function Provider(props) {
    const {
      load,
      resolved
    } = (0, _hooks.useAsync)(resolver, {
      assets: _types.AssetTiming.Immediate
    });
    (0, _react.useEffect)(() => {
      load();
    }, [load]);
    return /*#__PURE__*/_react.default.createElement(Context.Provider, Object.assign({
      value: resolved
    }, props));
  }

  function Consumer(props) {
    return /*#__PURE__*/_react.default.createElement(Context.Consumer, props);
  }

  function usePreload() {
    return (0, _hooks.useAsync)(resolver, {
      assets: _types.AssetTiming.NextPage
    }).load;
  }

  function Preload() {
    const preload = usePreload();
    (0, _reactIdle.useIdleCallback)(preload);
    return null;
  }

  function Prefetch() {
    const preload = usePreload();
    (0, _react.useEffect)(() => {
      preload();
    }, [preload]);
    return null;
  }

  const FinalComponent = Root;
  Reflect.defineProperty(FinalComponent, 'resolver', {
    value: resolver,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'Provider', {
    value: Provider,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'Consumer', {
    value: Consumer,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'Context', {
    value: Context,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'Preload', {
    value: Preload,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'Prefetch', {
    value: Prefetch,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'KeepFresh', {
    value: Preload,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'usePreload', {
    value: usePreload,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'usePrefetch', {
    value: usePreload,
    writable: false
  });
  Reflect.defineProperty(FinalComponent, 'useKeepFresh', {
    value: usePreload,
    writable: false
  });
  return FinalComponent;
}

/***/ }),

/***/ "./node_modules/@shopify/react-async/build/esnext/types.esnext":
/*!*********************************************************************!*\
  !*** ./node_modules/@shopify/react-async/build/esnext/types.esnext ***!
  \*********************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.AssetTiming = void 0;
let AssetTiming;
exports.AssetTiming = AssetTiming;

(function (AssetTiming) {
  AssetTiming[AssetTiming["None"] = 1] = "None";
  AssetTiming[AssetTiming["NextPage"] = 2] = "NextPage";
  AssetTiming[AssetTiming["CurrentPage"] = 3] = "CurrentPage";
  AssetTiming[AssetTiming["Immediate"] = 4] = "Immediate";
})(AssetTiming || (exports.AssetTiming = AssetTiming = {}));

/***/ }),

/***/ "./node_modules/@shopify/react-async/index.esnext":
/*!********************************************************!*\
  !*** ./node_modules/@shopify/react-async/index.esnext ***!
  \********************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});

var _index = __webpack_require__(/*! ./build/esnext/index.esnext */ "./node_modules/@shopify/react-async/build/esnext/index.esnext");

Object.keys(_index).forEach(function (key) {
  if (key === "default" || key === "__esModule") return;
  if (key in exports && exports[key] === _index[key]) return;
  Object.defineProperty(exports, key, {
    enumerable: true,
    get: function () {
      return _index[key];
    }
  });
});

/***/ }),

/***/ "./node_modules/@shopify/react-server/build/esnext/index.esnext":
/*!**********************************************************************!*\
  !*** ./node_modules/@shopify/react-server/build/esnext/index.esnext ***!
  \**********************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
Object.defineProperty(exports, "createRender", {
  enumerable: true,
  get: function () {
    return _render.createRender;
  }
});
Object.defineProperty(exports, "createServer", {
  enumerable: true,
  get: function () {
    return _server.createServer;
  }
});
Object.defineProperty(exports, "requestLogger", {
  enumerable: true,
  get: function () {
    return _logger.requestLogger;
  }
});

var _server = __webpack_require__(/*! ./server/server.esnext */ "./node_modules/@shopify/react-server/build/esnext/server/server.esnext");

var _render = __webpack_require__(/*! ./render/render.esnext */ "./node_modules/@shopify/react-server/build/esnext/render/render.esnext");

var _logger = __webpack_require__(/*! ./logger/logger.esnext */ "./node_modules/@shopify/react-server/build/esnext/logger/logger.esnext");

/***/ }),

/***/ "./node_modules/@shopify/react-server/build/esnext/logger/logger.esnext":
/*!******************************************************************************!*\
  !*** ./node_modules/@shopify/react-server/build/esnext/logger/logger.esnext ***!
  \******************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.Logger = exports.LOGGER = void 0;
exports.getLogger = getLogger;
exports.requestLogger = requestLogger;
exports.setLogger = setLogger;

var _chalk = _interopRequireDefault(__webpack_require__(/*! chalk */ "chalk"));

var _reactNetwork = __webpack_require__(/*! @shopify/react-network */ "@shopify/react-network");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

/* eslint-disable no-process-env */
const LOGGER = Symbol('logger');
exports.LOGGER = LOGGER;

const PREFIX = _chalk.default.underline('[React Server] ');

class Logger {
  constructor() {
    this.buffer = '';
    this.logger = console;
  }

  log(message) {
    if (true) {
      this.logger.log(`${PREFIX}${message}`);
    } else {}
  }

}

exports.Logger = Logger;

function setLogger(ctx, logger) {
  ctx.state[LOGGER] = logger;
}

function getLogger(ctx) {
  return ctx.state[LOGGER];
}

function initialRequestMessage(request) {
  const requestMethod = `${request.method.toUpperCase()} "${request.url}"`;
  return `Started ${requestMethod} at ${new Date().toISOString()}`;
}

function endRequestMessage(ctx, requestDuration) {
  const httpStatus = `${ctx.status} ${ctx.message || ''}`;
  const duration = `${requestDuration.toFixed(0)}ms`;
  return `Completed ${httpStatus} at ${new Date().toISOString()} in ${duration}`;
}

function endRequest(ctx, requestDuration) {
  const logger = getLogger(ctx);
  logger.log(endRequestMessage(ctx, requestDuration));

  if (true) {
    return;
  }
  /* eslint-disable @typescript-eslint/naming-convention */


  const logObject = {
    datetime: new Date().toISOString(),
    http_method: ctx.method.toUpperCase(),
    http_response: ctx.message || '',
    http_status: ctx.status,
    hostname: ctx.request.hostname,
    ips: ctx.request.ips,
    request_id: ctx.header['X-Request-ID'],
    uri: ctx.originalUrl,
    user_agent: ctx.header[_reactNetwork.Header.UserAgent],
    payload: logger.buffer
  };
  /* eslint-enable @typescript-eslint/naming-convention */
  // eslint-disable-next-line no-console

  console.log(JSON.stringify(logObject, undefined,  false ? undefined : 2));
}

function requestDuration(requestStartTime) {
  const duration = process.hrtime(requestStartTime);
  const ms = duration[0] * 1000 + duration[1] / 1e6;
  return Math.round(ms);
}

async function requestLogger(ctx, next) {
  const requestStartTime = process.hrtime();
  setLogger(ctx, new Logger());
  const logger = getLogger(ctx);
  logger.log(initialRequestMessage(ctx.request));

  try {
    await next();
  } catch (error) {
    logger.log('Error during server execution, see details below.');
    logger.log(`${error.stack || error.message || 'No stack trace was present'}`);
  } finally {
    endRequest(ctx, requestDuration(requestStartTime));
  }
}

/***/ }),

/***/ "./node_modules/@shopify/react-server/build/esnext/metrics/metrics.esnext":
/*!********************************************************************************!*\
  !*** ./node_modules/@shopify/react-server/build/esnext/metrics/metrics.esnext ***!
  \********************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.metricsMiddleware = void 0;

var _koaCompose = _interopRequireDefault(__webpack_require__(/*! koa-compose */ "koa-compose"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

const MILLIS_PER_SECOND = 1000;
const NANOS_PER_MILLIS = 1e6;
const START_TIME_STATE_KEY = Symbol('startTime');

async function startRequestTiming(ctx, next) {
  ctx.state[START_TIME_STATE_KEY] = process.hrtime();
  await next();
}

async function middleware(ctx, next) {
  try {
    await next();
  } finally {
    const [seconds, nanoseconds] = process.hrtime(ctx.state[START_TIME_STATE_KEY]);
    const ms = seconds * MILLIS_PER_SECOND + nanoseconds / NANOS_PER_MILLIS;
    const requestTime = Math.round(ms);
    const uiMetrics = `ui;request_time=${requestTime}`;
    ctx.set('Server-Timing', uiMetrics);
  }
}

const metricsMiddleware = (0, _koaCompose.default)([startRequestTiming, middleware]);
exports.metricsMiddleware = metricsMiddleware;

/***/ }),

/***/ "./node_modules/@shopify/react-server/build/esnext/ping/ping.esnext":
/*!**************************************************************************!*\
  !*** ./node_modules/@shopify/react-server/build/esnext/ping/ping.esnext ***!
  \**************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.ping = ping;

var _network = __webpack_require__(/*! @shopify/network */ "@shopify/network");

function ping(ctx) {
  ctx.status = _network.StatusCode.Ok;
  ctx.body = 'Pong';
}

/***/ }),

/***/ "./node_modules/@shopify/react-server/build/esnext/quilt-data/middleware.esnext":
/*!**************************************************************************************!*\
  !*** ./node_modules/@shopify/react-server/build/esnext/quilt-data/middleware.esnext ***!
  \**************************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.HEADER = void 0;
exports.quiltDataMiddleware = quiltDataMiddleware;
const HEADER = 'x-quilt-data';
exports.HEADER = HEADER;

async function quiltDataMiddleware(ctx, next) {
  const rawQuiltData = ctx.headers && ctx.headers[HEADER];

  if (rawQuiltData) {
    ctx.state.quiltData = JSON.parse(rawQuiltData);
  }

  await next();
}

/***/ }),

/***/ "./node_modules/@shopify/react-server/build/esnext/render/error/fallback-error-markup.esnext":
/*!***************************************************************************************************!*\
  !*** ./node_modules/@shopify/react-server/build/esnext/render/error/fallback-error-markup.esnext ***!
  \***************************************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.fallbackErrorMarkup = void 0;
const fallbackErrorMarkup = `
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta http-equiv="X-UA-Compatible" content="ie=edge" />
    <link
      rel="stylesheet"
      href="https://unpkg.com/@shopify/polaris@4.24.0/styles.min.css"
    />
    <title>Server Error</title>
  </head>
  <body>
    <div
      style="
        --top-bar-background: #00848e;
        --top-bar-background-lighter: #1d9ba4;
        --top-bar-color: #f9fafb;
        --p-frame-offset: 0px;
      "
    >
      <div class="Polaris-Page Polaris-Page--fullWidth">
        <div class="Polaris-Page__Content">
          <div
            style="
              --top-bar-background: #00848e;
              --top-bar-background-lighter: #1d9ba4;
              --top-bar-color: #f9fafb;
              --p-frame-offset: 0px;
            "
          >
            <div class="Polaris-EmptyState Polaris-EmptyState--withinPage">
              <div class="Polaris-EmptyState__Section">
                <div class="Polaris-EmptyState__DetailsContainer">
                  <div class="Polaris-EmptyState__Details">
                    <div class="Polaris-TextContainer">
                      <p
                        class="Polaris-DisplayText Polaris-DisplayText--sizeMedium"
                      >
                      This page is not available right now
                      </p>
                      <div class="Polaris-EmptyState__Content">
                        <p>
                          Please check back later.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="Polaris-EmptyState__ImageContainer">
                  <img
                    src="https://cdn.shopify.com/shopifycloud/web-foundation/images/error.svg"
                    role="presentation"
                    alt=""
                    class="Polaris-EmptyState__Image"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </body>
</html>
`;
exports.fallbackErrorMarkup = fallbackErrorMarkup;

/***/ }),

/***/ "./node_modules/@shopify/react-server/build/esnext/render/render.esnext":
/*!******************************************************************************!*\
  !*** ./node_modules/@shopify/react-server/build/esnext/render/render.esnext ***!
  \******************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.createRender = createRender;

var _path = __webpack_require__(/*! path */ "path");

var _fs = __webpack_require__(/*! fs */ "fs");

var _react = _interopRequireDefault(__webpack_require__(/*! react */ "react"));

var _koaCompose = _interopRequireDefault(__webpack_require__(/*! koa-compose */ "koa-compose"));

var _server = __webpack_require__(/*! @shopify/react-html/server */ "@shopify/react-html/server");

var _reactHtml = __webpack_require__(/*! @shopify/react-html */ "@shopify/react-html");

var _server2 = __webpack_require__(/*! @shopify/react-network/server */ "@shopify/react-network/server");

var _server3 = __webpack_require__(/*! @shopify/react-effect/server */ "@shopify/react-effect/server");

var _reactHydrate = __webpack_require__(/*! @shopify/react-hydrate */ "@shopify/react-hydrate");

var _reactAsync = __webpack_require__(/*! @shopify/react-async */ "./node_modules/@shopify/react-async/index.esnext");

var _reactNetwork = __webpack_require__(/*! @shopify/react-network */ "@shopify/react-network");

var _sewingKitKoa = __webpack_require__(/*! @shopify/sewing-kit-koa */ "@shopify/sewing-kit-koa");

var _middleware = __webpack_require__(/*! ../quilt-data/middleware.esnext */ "./node_modules/@shopify/react-server/build/esnext/quilt-data/middleware.esnext");

var _logger = __webpack_require__(/*! ../logger/logger.esnext */ "./node_modules/@shopify/react-server/build/esnext/logger/logger.esnext");

var _fallbackErrorMarkup = __webpack_require__(/*! ./error/fallback-error-markup.esnext */ "./node_modules/@shopify/react-server/build/esnext/render/error/fallback-error-markup.esnext");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

/**
 * Creates a Koa middleware for rendering an `@shopify/react-html` based React application defined by `render`.
 * @param render
 * @param options
 */
function createRender(render$1, options = {}) {
  const manifestPath = getManifestPath(process.cwd());
  const {
    assetPrefix,
    assetName: assetNameInput = 'main',
    renderError,
    renderRawErrorMessage,
    htmlProps: htmlPropsInput = {}
  } = options;

  async function renderFunction(ctx) {
    const assetName = typeof assetNameInput === 'function' ? assetNameInput(ctx) : assetNameInput;
    const {
      scripts: additionalScripts = [],
      styles: additionalStyles = [],
      ...additionalHtmlProps
    } = typeof htmlPropsInput === 'function' ? htmlPropsInput(ctx) : htmlPropsInput;
    const logger = (0, _logger.getLogger)(ctx) || console;
    const assets = (0, _sewingKitKoa.getAssets)(ctx);
    const networkManager = new _server2.NetworkManager({
      headers: ctx.headers,
      cookies: ctx.request.headers.cookie || ''
    });
    const htmlManager = new _server.HtmlManager();
    const asyncAssetManager = new _reactAsync.AsyncAssetManager();
    const hydrationManager = new _reactHydrate.HydrationManager();

    function Providers({
      children
    }) {
      const [, Serialize] = (0, _reactHtml.useSerialized)('quilt-data');
      return /*#__PURE__*/_react.default.createElement(_reactAsync.AsyncAssetContext.Provider, {
        value: asyncAssetManager
      }, /*#__PURE__*/_react.default.createElement(_reactHydrate.HydrationContext.Provider, {
        value: hydrationManager
      }, /*#__PURE__*/_react.default.createElement(_server2.NetworkContext.Provider, {
        value: networkManager
      }, children, /*#__PURE__*/_react.default.createElement(Serialize, {
        data: () => ctx.state.quiltData
      }))));
    }

    try {
      const app = render$1(ctx);
      await (0, _server3.extract)(app, {
        decorate(element) {
          return /*#__PURE__*/_react.default.createElement(_server.HtmlContext.Provider, {
            value: htmlManager
          }, /*#__PURE__*/_react.default.createElement(Providers, null, element));
        },

        afterEachPass({
          renderDuration,
          resolveDuration,
          index,
          finished
        }) {
          const pass = `Pass number ${index} ${finished ? ' (this was the final pass)' : ''}`;
          const rendering = `Rendering took ${renderDuration}ms`;
          const resolving = `Resolving promises took ${resolveDuration}ms`;
          logger.log(pass);
          logger.log(rendering);
          logger.log(resolving);
        },

        ...options
      });
      (0, _server2.applyToContext)(ctx, networkManager);
      const immediateAsyncAssets = asyncAssetManager.used(_reactAsync.AssetTiming.Immediate);
      const [styles, scripts] = await Promise.all([assets.styles({
        name: assetName,
        asyncAssets: immediateAsyncAssets
      }), assets.scripts({
        name: assetName,
        asyncAssets: immediateAsyncAssets
      })]);
      styles.push(...additionalStyles);
      scripts.push(...additionalScripts);
      const response = (0, _server.stream)( /*#__PURE__*/_react.default.createElement(_server.Html, Object.assign({}, additionalHtmlProps, {
        manager: htmlManager,
        styles: styles,
        scripts: scripts
      }), /*#__PURE__*/_react.default.createElement(Providers, null, app)));
      ctx.set(_reactNetwork.Header.ContentType, 'text/html');
      ctx.body = response;
    } catch (error) {
      const errorMessage = `React server-side rendering error:\n${error.stack || error.message}`;
      logger.log(errorMessage);
      ctx.status = _reactNetwork.StatusCode.InternalServerError;
      ctx.state.quiltError = error;

      if (renderRawErrorMessage) {
        ctx.body = errorMessage;
      } else {
        if (renderError) {
          const [styles, scripts] = await Promise.all([assets.styles({
            name: 'error'
          }), assets.scripts({
            name: 'error'
          })]);
          const response = (0, _server.render)( /*#__PURE__*/_react.default.createElement(_server.Html, {
            manager: htmlManager,
            styles: styles,
            scripts: scripts
          }, renderError(ctx)));
          ctx.body = response;
        } else {
          ctx.body = _fallbackErrorMarkup.fallbackErrorMarkup;
          ctx.set(_reactNetwork.Header.ContentType, 'text/html');
        }

        ctx.throw(_reactNetwork.StatusCode.InternalServerError, error);
      }
    }
  }

  return (0, _koaCompose.default)([_middleware.quiltDataMiddleware, (0, _sewingKitKoa.middleware)({
    assetPrefix,
    manifestPath
  }), renderFunction]);
}

function getManifestPath(root) {
  const gemFileExists = (0, _fs.existsSync)((0, _path.join)(root, 'Gemfile'));

  if (!gemFileExists) {
    return;
  } // eslint-disable-next-line no-process-env


  return  true ? `tmp/sewing-kit/sewing-kit-manifest.json` : undefined;
}

/***/ }),

/***/ "./node_modules/@shopify/react-server/build/esnext/server/server.esnext":
/*!******************************************************************************!*\
  !*** ./node_modules/@shopify/react-server/build/esnext/server/server.esnext ***!
  \******************************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.createServer = createServer;

__webpack_require__(/*! cross-fetch */ "cross-fetch");

var _koa = _interopRequireDefault(__webpack_require__(/*! koa */ "koa"));

var _koaCompose = _interopRequireDefault(__webpack_require__(/*! koa-compose */ "koa-compose"));

var _koaMount = _interopRequireDefault(__webpack_require__(/*! koa-mount */ "koa-mount"));

var _ping = __webpack_require__(/*! ../ping/ping.esnext */ "./node_modules/@shopify/react-server/build/esnext/ping/ping.esnext");

var _logger = __webpack_require__(/*! ../logger/logger.esnext */ "./node_modules/@shopify/react-server/build/esnext/logger/logger.esnext");

var _metrics = __webpack_require__(/*! ../metrics/metrics.esnext */ "./node_modules/@shopify/react-server/build/esnext/metrics/metrics.esnext");

var _render = __webpack_require__(/*! ../render/render.esnext */ "./node_modules/@shopify/react-server/build/esnext/render/render.esnext");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

const logger = console;
/**
 * Create a full Koa server for server rendering an `@shopify/react-html` based React application defined by `options.render`
 * @param options
 * @returns a Server instance
 */

function createServer(options) {
  const {
    /* eslint-disable no-process-env */
    ip = process.env.REACT_SERVER_IP && process.env.REACT_SERVER_IP !== 'undefined' ? process.env.REACT_SERVER_IP : '0.0.0.0',
    port = process.env.REACT_SERVER_PORT && process.env.REACT_SERVER_PORT !== 'undefined' ? parseInt(process.env.REACT_SERVER_PORT, 10) : 8081,
    // a default is set in sewingKitMiddleware
    assetPrefix = process.env.CDN_URL && process.env.CDN_URL !== 'undefined' ? process.env.CDN_URL : undefined,
    render,
    renderError,
    renderRawErrorMessage = "development" === 'development',

    /* eslint-enable no-process-env */
    serverMiddleware,
    assetName,
    htmlProps,
    proxy = false,
    app = new _koa.default()
  } = options;
  app.proxy = proxy;
  app.use((0, _koaMount.default)('/services/ping', _ping.ping));
  app.use(_logger.requestLogger);
  app.use(_metrics.metricsMiddleware);

  if (serverMiddleware) {
    app.use((0, _koaCompose.default)(serverMiddleware));
  }

  app.use((0, _render.createRender)(render, {
    assetPrefix,
    assetName,
    renderError,
    renderRawErrorMessage,
    htmlProps
  }));
  return app.listen(port, ip, () => {
    logger.log(`started react-server on ${ip}:${port}`);
  });
}

/***/ }),

/***/ "./node_modules/@shopify/react-server/index.esnext":
/*!*********************************************************!*\
  !*** ./node_modules/@shopify/react-server/index.esnext ***!
  \*********************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

"use strict";


Object.defineProperty(exports, "__esModule", {
  value: true
});

var _index = __webpack_require__(/*! ./build/esnext/index.esnext */ "./node_modules/@shopify/react-server/build/esnext/index.esnext");

Object.keys(_index).forEach(function (key) {
  if (key === "default" || key === "__esModule") return;
  if (key in exports && exports[key] === _index[key]) return;
  Object.defineProperty(exports, key, {
    enumerable: true,
    get: function () {
      return _index[key];
    }
  });
});

/***/ }),

/***/ "./node_modules/source-map-support/register.js":
/*!*****************************************************!*\
  !*** ./node_modules/source-map-support/register.js ***!
  \*****************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

__webpack_require__(/*! ./ */ "./node_modules/source-map-support/source-map-support.js").install();


/***/ }),

/***/ "./node_modules/source-map-support/source-map-support.js":
/*!***************************************************************!*\
  !*** ./node_modules/source-map-support/source-map-support.js ***!
  \***************************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

/* WEBPACK VAR INJECTION */(function(module) {var SourceMapConsumer = __webpack_require__(/*! source-map */ "source-map").SourceMapConsumer;
var path = __webpack_require__(/*! path */ "path");

var fs;
try {
  fs = __webpack_require__(/*! fs */ "fs");
  if (!fs.existsSync || !fs.readFileSync) {
    // fs doesn't have all methods we need
    fs = null;
  }
} catch (err) {
  /* nop */
}

var bufferFrom = __webpack_require__(/*! buffer-from */ "buffer-from");

/**
 * Requires a module which is protected against bundler minification.
 *
 * @param {NodeModule} mod
 * @param {string} request
 */
function dynamicRequire(mod, request) {
  return mod.require(request);
}

// Only install once if called multiple times
var errorFormatterInstalled = false;
var uncaughtShimInstalled = false;

// If true, the caches are reset before a stack trace formatting operation
var emptyCacheBetweenOperations = false;

// Supports {browser, node, auto}
var environment = "auto";

// Maps a file path to a string containing the file contents
var fileContentsCache = {};

// Maps a file path to a source map for that file
var sourceMapCache = {};

// Regex for detecting source maps
var reSourceMap = /^data:application\/json[^,]+base64,/;

// Priority list of retrieve handlers
var retrieveFileHandlers = [];
var retrieveMapHandlers = [];

function isInBrowser() {
  if (environment === "browser")
    return true;
  if (environment === "node")
    return false;
  return ((typeof window !== 'undefined') && (typeof XMLHttpRequest === 'function') && !(window.require && window.module && window.process && window.process.type === "renderer"));
}

function hasGlobalProcessEventEmitter() {
  return ((typeof process === 'object') && (process !== null) && (typeof process.on === 'function'));
}

function globalProcessVersion() {
  if ((typeof process === 'object') && (process !== null)) {
    return process.version;
  } else {
    return '';
  }
}

function globalProcessStderr() {
  if ((typeof process === 'object') && (process !== null)) {
    return process.stderr;
  }
}

function globalProcessExit(code) {
  if ((typeof process === 'object') && (process !== null) && (typeof process.exit === 'function')) {
    return process.exit(code);
  }
}

function handlerExec(list) {
  return function(arg) {
    for (var i = 0; i < list.length; i++) {
      var ret = list[i](arg);
      if (ret) {
        return ret;
      }
    }
    return null;
  };
}

var retrieveFile = handlerExec(retrieveFileHandlers);

retrieveFileHandlers.push(function(path) {
  // Trim the path to make sure there is no extra whitespace.
  path = path.trim();
  if (/^file:/.test(path)) {
    // existsSync/readFileSync can't handle file protocol, but once stripped, it works
    path = path.replace(/file:\/\/\/(\w:)?/, function(protocol, drive) {
      return drive ?
        '' : // file:///C:/dir/file -> C:/dir/file
        '/'; // file:///root-dir/file -> /root-dir/file
    });
  }
  if (path in fileContentsCache) {
    return fileContentsCache[path];
  }

  var contents = '';
  try {
    if (!fs) {
      // Use SJAX if we are in the browser
      var xhr = new XMLHttpRequest();
      xhr.open('GET', path, /** async */ false);
      xhr.send(null);
      if (xhr.readyState === 4 && xhr.status === 200) {
        contents = xhr.responseText;
      }
    } else if (fs.existsSync(path)) {
      // Otherwise, use the filesystem
      contents = fs.readFileSync(path, 'utf8');
    }
  } catch (er) {
    /* ignore any errors */
  }

  return fileContentsCache[path] = contents;
});

// Support URLs relative to a directory, but be careful about a protocol prefix
// in case we are in the browser (i.e. directories may start with "http://" or "file:///")
function supportRelativeURL(file, url) {
  if (!file) return url;
  var dir = path.dirname(file);
  var match = /^\w+:\/\/[^\/]*/.exec(dir);
  var protocol = match ? match[0] : '';
  var startPath = dir.slice(protocol.length);
  if (protocol && /^\/\w\:/.test(startPath)) {
    // handle file:///C:/ paths
    protocol += '/';
    return protocol + path.resolve(dir.slice(protocol.length), url).replace(/\\/g, '/');
  }
  return protocol + path.resolve(dir.slice(protocol.length), url);
}

function retrieveSourceMapURL(source) {
  var fileData;

  if (isInBrowser()) {
     try {
       var xhr = new XMLHttpRequest();
       xhr.open('GET', source, false);
       xhr.send(null);
       fileData = xhr.readyState === 4 ? xhr.responseText : null;

       // Support providing a sourceMappingURL via the SourceMap header
       var sourceMapHeader = xhr.getResponseHeader("SourceMap") ||
                             xhr.getResponseHeader("X-SourceMap");
       if (sourceMapHeader) {
         return sourceMapHeader;
       }
     } catch (e) {
     }
  }

  // Get the URL of the source map
  fileData = retrieveFile(source);
  var re = /(?:\/\/[@#][\s]*sourceMappingURL=([^\s'"]+)[\s]*$)|(?:\/\*[@#][\s]*sourceMappingURL=([^\s*'"]+)[\s]*(?:\*\/)[\s]*$)/mg;
  // Keep executing the search to find the *last* sourceMappingURL to avoid
  // picking up sourceMappingURLs from comments, strings, etc.
  var lastMatch, match;
  while (match = re.exec(fileData)) lastMatch = match;
  if (!lastMatch) return null;
  return lastMatch[1];
};

// Can be overridden by the retrieveSourceMap option to install. Takes a
// generated source filename; returns a {map, optional url} object, or null if
// there is no source map.  The map field may be either a string or the parsed
// JSON object (ie, it must be a valid argument to the SourceMapConsumer
// constructor).
var retrieveSourceMap = handlerExec(retrieveMapHandlers);
retrieveMapHandlers.push(function(source) {
  var sourceMappingURL = retrieveSourceMapURL(source);
  if (!sourceMappingURL) return null;

  // Read the contents of the source map
  var sourceMapData;
  if (reSourceMap.test(sourceMappingURL)) {
    // Support source map URL as a data url
    var rawData = sourceMappingURL.slice(sourceMappingURL.indexOf(',') + 1);
    sourceMapData = bufferFrom(rawData, "base64").toString();
    sourceMappingURL = source;
  } else {
    // Support source map URLs relative to the source URL
    sourceMappingURL = supportRelativeURL(source, sourceMappingURL);
    sourceMapData = retrieveFile(sourceMappingURL);
  }

  if (!sourceMapData) {
    return null;
  }

  return {
    url: sourceMappingURL,
    map: sourceMapData
  };
});

function mapSourcePosition(position) {
  var sourceMap = sourceMapCache[position.source];
  if (!sourceMap) {
    // Call the (overrideable) retrieveSourceMap function to get the source map.
    var urlAndMap = retrieveSourceMap(position.source);
    if (urlAndMap) {
      sourceMap = sourceMapCache[position.source] = {
        url: urlAndMap.url,
        map: new SourceMapConsumer(urlAndMap.map)
      };

      // Load all sources stored inline with the source map into the file cache
      // to pretend like they are already loaded. They may not exist on disk.
      if (sourceMap.map.sourcesContent) {
        sourceMap.map.sources.forEach(function(source, i) {
          var contents = sourceMap.map.sourcesContent[i];
          if (contents) {
            var url = supportRelativeURL(sourceMap.url, source);
            fileContentsCache[url] = contents;
          }
        });
      }
    } else {
      sourceMap = sourceMapCache[position.source] = {
        url: null,
        map: null
      };
    }
  }

  // Resolve the source URL relative to the URL of the source map
  if (sourceMap && sourceMap.map && typeof sourceMap.map.originalPositionFor === 'function') {
    var originalPosition = sourceMap.map.originalPositionFor(position);

    // Only return the original position if a matching line was found. If no
    // matching line is found then we return position instead, which will cause
    // the stack trace to print the path and line for the compiled file. It is
    // better to give a precise location in the compiled file than a vague
    // location in the original file.
    if (originalPosition.source !== null) {
      originalPosition.source = supportRelativeURL(
        sourceMap.url, originalPosition.source);
      return originalPosition;
    }
  }

  return position;
}

// Parses code generated by FormatEvalOrigin(), a function inside V8:
// https://code.google.com/p/v8/source/browse/trunk/src/messages.js
function mapEvalOrigin(origin) {
  // Most eval() calls are in this format
  var match = /^eval at ([^(]+) \((.+):(\d+):(\d+)\)$/.exec(origin);
  if (match) {
    var position = mapSourcePosition({
      source: match[2],
      line: +match[3],
      column: match[4] - 1
    });
    return 'eval at ' + match[1] + ' (' + position.source + ':' +
      position.line + ':' + (position.column + 1) + ')';
  }

  // Parse nested eval() calls using recursion
  match = /^eval at ([^(]+) \((.+)\)$/.exec(origin);
  if (match) {
    return 'eval at ' + match[1] + ' (' + mapEvalOrigin(match[2]) + ')';
  }

  // Make sure we still return useful information if we didn't find anything
  return origin;
}

// This is copied almost verbatim from the V8 source code at
// https://code.google.com/p/v8/source/browse/trunk/src/messages.js. The
// implementation of wrapCallSite() used to just forward to the actual source
// code of CallSite.prototype.toString but unfortunately a new release of V8
// did something to the prototype chain and broke the shim. The only fix I
// could find was copy/paste.
function CallSiteToString() {
  var fileName;
  var fileLocation = "";
  if (this.isNative()) {
    fileLocation = "native";
  } else {
    fileName = this.getScriptNameOrSourceURL();
    if (!fileName && this.isEval()) {
      fileLocation = this.getEvalOrigin();
      fileLocation += ", ";  // Expecting source position to follow.
    }

    if (fileName) {
      fileLocation += fileName;
    } else {
      // Source code does not originate from a file and is not native, but we
      // can still get the source position inside the source string, e.g. in
      // an eval string.
      fileLocation += "<anonymous>";
    }
    var lineNumber = this.getLineNumber();
    if (lineNumber != null) {
      fileLocation += ":" + lineNumber;
      var columnNumber = this.getColumnNumber();
      if (columnNumber) {
        fileLocation += ":" + columnNumber;
      }
    }
  }

  var line = "";
  var functionName = this.getFunctionName();
  var addSuffix = true;
  var isConstructor = this.isConstructor();
  var isMethodCall = !(this.isToplevel() || isConstructor);
  if (isMethodCall) {
    var typeName = this.getTypeName();
    // Fixes shim to be backward compatable with Node v0 to v4
    if (typeName === "[object Object]") {
      typeName = "null";
    }
    var methodName = this.getMethodName();
    if (functionName) {
      if (typeName && functionName.indexOf(typeName) != 0) {
        line += typeName + ".";
      }
      line += functionName;
      if (methodName && functionName.indexOf("." + methodName) != functionName.length - methodName.length - 1) {
        line += " [as " + methodName + "]";
      }
    } else {
      line += typeName + "." + (methodName || "<anonymous>");
    }
  } else if (isConstructor) {
    line += "new " + (functionName || "<anonymous>");
  } else if (functionName) {
    line += functionName;
  } else {
    line += fileLocation;
    addSuffix = false;
  }
  if (addSuffix) {
    line += " (" + fileLocation + ")";
  }
  return line;
}

function cloneCallSite(frame) {
  var object = {};
  Object.getOwnPropertyNames(Object.getPrototypeOf(frame)).forEach(function(name) {
    object[name] = /^(?:is|get)/.test(name) ? function() { return frame[name].call(frame); } : frame[name];
  });
  object.toString = CallSiteToString;
  return object;
}

function wrapCallSite(frame, state) {
  // provides interface backward compatibility
  if (state === undefined) {
    state = { nextPosition: null, curPosition: null }
  }
  if(frame.isNative()) {
    state.curPosition = null;
    return frame;
  }

  // Most call sites will return the source file from getFileName(), but code
  // passed to eval() ending in "//# sourceURL=..." will return the source file
  // from getScriptNameOrSourceURL() instead
  var source = frame.getFileName() || frame.getScriptNameOrSourceURL();
  if (source) {
    var line = frame.getLineNumber();
    var column = frame.getColumnNumber() - 1;

    // Fix position in Node where some (internal) code is prepended.
    // See https://github.com/evanw/node-source-map-support/issues/36
    // Header removed in node at ^10.16 || >=11.11.0
    // v11 is not an LTS candidate, we can just test the one version with it.
    // Test node versions for: 10.16-19, 10.20+, 12-19, 20-99, 100+, or 11.11
    var noHeader = /^v(10\.1[6-9]|10\.[2-9][0-9]|10\.[0-9]{3,}|1[2-9]\d*|[2-9]\d|\d{3,}|11\.11)/;
    var headerLength = noHeader.test(globalProcessVersion()) ? 0 : 62;
    if (line === 1 && column > headerLength && !isInBrowser() && !frame.isEval()) {
      column -= headerLength;
    }

    var position = mapSourcePosition({
      source: source,
      line: line,
      column: column
    });
    state.curPosition = position;
    frame = cloneCallSite(frame);
    var originalFunctionName = frame.getFunctionName;
    frame.getFunctionName = function() {
      if (state.nextPosition == null) {
        return originalFunctionName();
      }
      return state.nextPosition.name || originalFunctionName();
    };
    frame.getFileName = function() { return position.source; };
    frame.getLineNumber = function() { return position.line; };
    frame.getColumnNumber = function() { return position.column + 1; };
    frame.getScriptNameOrSourceURL = function() { return position.source; };
    return frame;
  }

  // Code called using eval() needs special handling
  var origin = frame.isEval() && frame.getEvalOrigin();
  if (origin) {
    origin = mapEvalOrigin(origin);
    frame = cloneCallSite(frame);
    frame.getEvalOrigin = function() { return origin; };
    return frame;
  }

  // If we get here then we were unable to change the source position
  return frame;
}

// This function is part of the V8 stack trace API, for more info see:
// https://v8.dev/docs/stack-trace-api
function prepareStackTrace(error, stack) {
  if (emptyCacheBetweenOperations) {
    fileContentsCache = {};
    sourceMapCache = {};
  }

  var name = error.name || 'Error';
  var message = error.message || '';
  var errorString = name + ": " + message;

  var state = { nextPosition: null, curPosition: null };
  var processedStack = [];
  for (var i = stack.length - 1; i >= 0; i--) {
    processedStack.push('\n    at ' + wrapCallSite(stack[i], state));
    state.nextPosition = state.curPosition;
  }
  state.curPosition = state.nextPosition = null;
  return errorString + processedStack.reverse().join('');
}

// Generate position and snippet of original source with pointer
function getErrorSource(error) {
  var match = /\n    at [^(]+ \((.*):(\d+):(\d+)\)/.exec(error.stack);
  if (match) {
    var source = match[1];
    var line = +match[2];
    var column = +match[3];

    // Support the inline sourceContents inside the source map
    var contents = fileContentsCache[source];

    // Support files on disk
    if (!contents && fs && fs.existsSync(source)) {
      try {
        contents = fs.readFileSync(source, 'utf8');
      } catch (er) {
        contents = '';
      }
    }

    // Format the line from the original source code like node does
    if (contents) {
      var code = contents.split(/(?:\r\n|\r|\n)/)[line - 1];
      if (code) {
        return source + ':' + line + '\n' + code + '\n' +
          new Array(column).join(' ') + '^';
      }
    }
  }
  return null;
}

function printErrorAndExit (error) {
  var source = getErrorSource(error);

  // Ensure error is printed synchronously and not truncated
  var stderr = globalProcessStderr();
  if (stderr && stderr._handle && stderr._handle.setBlocking) {
    stderr._handle.setBlocking(true);
  }

  if (source) {
    console.error();
    console.error(source);
  }

  console.error(error.stack);
  globalProcessExit(1);
}

function shimEmitUncaughtException () {
  var origEmit = process.emit;

  process.emit = function (type) {
    if (type === 'uncaughtException') {
      var hasStack = (arguments[1] && arguments[1].stack);
      var hasListeners = (this.listeners(type).length > 0);

      if (hasStack && !hasListeners) {
        return printErrorAndExit(arguments[1]);
      }
    }

    return origEmit.apply(this, arguments);
  };
}

var originalRetrieveFileHandlers = retrieveFileHandlers.slice(0);
var originalRetrieveMapHandlers = retrieveMapHandlers.slice(0);

exports.wrapCallSite = wrapCallSite;
exports.getErrorSource = getErrorSource;
exports.mapSourcePosition = mapSourcePosition;
exports.retrieveSourceMap = retrieveSourceMap;

exports.install = function(options) {
  options = options || {};

  if (options.environment) {
    environment = options.environment;
    if (["node", "browser", "auto"].indexOf(environment) === -1) {
      throw new Error("environment " + environment + " was unknown. Available options are {auto, browser, node}")
    }
  }

  // Allow sources to be found by methods other than reading the files
  // directly from disk.
  if (options.retrieveFile) {
    if (options.overrideRetrieveFile) {
      retrieveFileHandlers.length = 0;
    }

    retrieveFileHandlers.unshift(options.retrieveFile);
  }

  // Allow source maps to be found by methods other than reading the files
  // directly from disk.
  if (options.retrieveSourceMap) {
    if (options.overrideRetrieveSourceMap) {
      retrieveMapHandlers.length = 0;
    }

    retrieveMapHandlers.unshift(options.retrieveSourceMap);
  }

  // Support runtime transpilers that include inline source maps
  if (options.hookRequire && !isInBrowser()) {
    // Use dynamicRequire to avoid including in browser bundles
    var Module = dynamicRequire(module, 'module');
    var $compile = Module.prototype._compile;

    if (!$compile.__sourceMapSupport) {
      Module.prototype._compile = function(content, filename) {
        fileContentsCache[filename] = content;
        sourceMapCache[filename] = undefined;
        return $compile.call(this, content, filename);
      };

      Module.prototype._compile.__sourceMapSupport = true;
    }
  }

  // Configure options
  if (!emptyCacheBetweenOperations) {
    emptyCacheBetweenOperations = 'emptyCacheBetweenOperations' in options ?
      options.emptyCacheBetweenOperations : false;
  }

  // Install the error reformatter
  if (!errorFormatterInstalled) {
    errorFormatterInstalled = true;
    Error.prepareStackTrace = prepareStackTrace;
  }

  if (!uncaughtShimInstalled) {
    var installHandler = 'handleUncaughtExceptions' in options ?
      options.handleUncaughtExceptions : true;

    // Do not override 'uncaughtException' with our own handler in Node.js
    // Worker threads. Workers pass the error to the main thread as an event,
    // rather than printing something to stderr and exiting.
    try {
      // We need to use `dynamicRequire` because `require` on it's own will be optimized by WebPack/Browserify.
      var worker_threads = dynamicRequire(module, 'worker_threads');
      if (worker_threads.isMainThread === false) {
        installHandler = false;
      }
    } catch(e) {}

    // Provide the option to not install the uncaught exception handler. This is
    // to support other uncaught exception handlers (in test frameworks, for
    // example). If this handler is not installed and there are no other uncaught
    // exception handlers, uncaught exceptions will be caught by node's built-in
    // exception handler and the process will still be terminated. However, the
    // generated JavaScript code will be shown above the stack trace instead of
    // the original source code.
    if (installHandler && hasGlobalProcessEventEmitter()) {
      uncaughtShimInstalled = true;
      shimEmitUncaughtException();
    }
  }
};

exports.resetRetrieveHandlers = function() {
  retrieveFileHandlers.length = 0;
  retrieveMapHandlers.length = 0;

  retrieveFileHandlers = originalRetrieveFileHandlers.slice(0);
  retrieveMapHandlers = originalRetrieveMapHandlers.slice(0);

  retrieveSourceMap = handlerExec(retrieveMapHandlers);
  retrieveFile = handlerExec(retrieveFileHandlers);
}

/* WEBPACK VAR INJECTION */}.call(this, __webpack_require__(/*! ./../webpack/buildin/module.js */ "./node_modules/webpack/buildin/module.js")(module)))

/***/ }),

/***/ "./node_modules/webpack/buildin/module.js":
/*!***********************************!*\
  !*** (webpack)/buildin/module.js ***!
  \***********************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = function(module) {
	if (!module.webpackPolyfill) {
		module.deprecate = function() {};
		module.paths = [];
		// module.parent = undefined by default
		if (!module.children) module.children = [];
		Object.defineProperty(module, "loaded", {
			enumerable: true,
			get: function() {
				return module.l;
			}
		});
		Object.defineProperty(module, "id", {
			enumerable: true,
			get: function() {
				return module.i;
			}
		});
		module.webpackPolyfill = 1;
	}
	return module;
};


/***/ }),

/***/ 0:
/*!*********************************************************!*\
  !*** multi source-map-support/register ./app/ui/server ***!
  \*********************************************************/
/*! no static exports found */
/***/ (function(module, exports, __webpack_require__) {

__webpack_require__(/*! source-map-support/register */"./node_modules/source-map-support/register.js");
module.exports = __webpack_require__(/*! /Users/sophiedeziel/dev/Tentacles/app/ui/server */"./app/ui/server.js");


/***/ }),

/***/ "@shopify/network":
/*!***********************************!*\
  !*** external "@shopify/network" ***!
  \***********************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/network");

/***/ }),

/***/ "@shopify/react-effect":
/*!****************************************!*\
  !*** external "@shopify/react-effect" ***!
  \****************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-effect");

/***/ }),

/***/ "@shopify/react-effect/server":
/*!***********************************************!*\
  !*** external "@shopify/react-effect/server" ***!
  \***********************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-effect/server");

/***/ }),

/***/ "@shopify/react-hooks":
/*!***************************************!*\
  !*** external "@shopify/react-hooks" ***!
  \***************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-hooks");

/***/ }),

/***/ "@shopify/react-html":
/*!**************************************!*\
  !*** external "@shopify/react-html" ***!
  \**************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-html");

/***/ }),

/***/ "@shopify/react-html/server":
/*!*********************************************!*\
  !*** external "@shopify/react-html/server" ***!
  \*********************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-html/server");

/***/ }),

/***/ "@shopify/react-hydrate":
/*!*****************************************!*\
  !*** external "@shopify/react-hydrate" ***!
  \*****************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-hydrate");

/***/ }),

/***/ "@shopify/react-idle":
/*!**************************************!*\
  !*** external "@shopify/react-idle" ***!
  \**************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-idle");

/***/ }),

/***/ "@shopify/react-intersection-observer":
/*!*******************************************************!*\
  !*** external "@shopify/react-intersection-observer" ***!
  \*******************************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-intersection-observer");

/***/ }),

/***/ "@shopify/react-network":
/*!*****************************************!*\
  !*** external "@shopify/react-network" ***!
  \*****************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-network");

/***/ }),

/***/ "@shopify/react-network/server":
/*!************************************************!*\
  !*** external "@shopify/react-network/server" ***!
  \************************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/react-network/server");

/***/ }),

/***/ "@shopify/sewing-kit-koa":
/*!******************************************!*\
  !*** external "@shopify/sewing-kit-koa" ***!
  \******************************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("@shopify/sewing-kit-koa");

/***/ }),

/***/ "buffer-from":
/*!******************************!*\
  !*** external "buffer-from" ***!
  \******************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("buffer-from");

/***/ }),

/***/ "chalk":
/*!************************!*\
  !*** external "chalk" ***!
  \************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("chalk");

/***/ }),

/***/ "cross-fetch":
/*!******************************!*\
  !*** external "cross-fetch" ***!
  \******************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("cross-fetch");

/***/ }),

/***/ "fs":
/*!*********************!*\
  !*** external "fs" ***!
  \*********************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("fs");

/***/ }),

/***/ "koa":
/*!**********************!*\
  !*** external "koa" ***!
  \**********************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("koa");

/***/ }),

/***/ "koa-compose":
/*!******************************!*\
  !*** external "koa-compose" ***!
  \******************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("koa-compose");

/***/ }),

/***/ "koa-mount":
/*!****************************!*\
  !*** external "koa-mount" ***!
  \****************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("koa-mount");

/***/ }),

/***/ "path":
/*!***********************!*\
  !*** external "path" ***!
  \***********************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("path");

/***/ }),

/***/ "react":
/*!************************!*\
  !*** external "react" ***!
  \************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("react");

/***/ }),

/***/ "source-map":
/*!*****************************!*\
  !*** external "source-map" ***!
  \*****************************/
/*! no static exports found */
/***/ (function(module, exports) {

module.exports = require("source-map");

/***/ })

/******/ });