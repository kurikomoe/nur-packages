// Nix's Node build is not recognized by node-addon-require-builtin's binary
// introspection. With --expose-internals, Node can load these modules directly.
const Module = require('node:module');
const originalLoad = Module._load;

// The upstream launcher delegates through process.execPath. Keep those child
// processes on the same wrapper, including its flags and compatibility preload.
if (process.env.DSH_NODE_EXECUTABLE) {
  process.execPath = process.env.DSH_NODE_EXECUTABLE;
}

Module._load = function (request, parent, isMain) {
  const exports = originalLoad.apply(this, arguments);
  if (request === 'node-addon-require-builtin' && process.execArgv.includes('--expose-internals')) {
    exports.requireBuiltin = id => originalLoad.call(this, id, parent, false);
    if (exports.default) exports.default.requireBuiltin = exports.requireBuiltin;
  }
  return exports;
};
