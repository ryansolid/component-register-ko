var LIFECYCLE_METHODS, Utils, ko;

ko = require('knockout');

Utils = require('component-register').Utils;

LIFECYCLE_METHODS = ['dispose'];

ko.isReleasable = function(obj, depth) {
  var i, key, len, method, value;
  if (depth == null) {
    depth = 0;
  }
  if ((!obj || (obj !== Object(obj))) || obj.__released) {
    return false;
  }
  if (ko.isObservable(obj)) {
    return true;
  }
  if (Utils.isFunction(obj) || obj instanceof Element) {
    return false;
  }
  for (i = 0, len = LIFECYCLE_METHODS.length; i < len; i++) {
    method = LIFECYCLE_METHODS[i];
    if (typeof obj[method] === 'function') {
      return true;
    }
  }
  if (depth > 0) {
    return false;
  }
  for (key in obj) {
    value = obj[key];
    if (ko.isReleasable(value, depth + 1)) {
      return true;
    }
  }
  return false;
};

ko.release = function(obj) {
  var fn, i, len;
  if (!ko.isReleasable(obj)) {
    return;
  }
  obj.__released = true;
  if (Array.isArray(obj)) {
    while (obj.length) {
      ko.release(obj.shift());
    }
    return;
  }
  if (ko.isObservable(obj) && !ko.isComputed(obj)) {
    ko.release(ko.unwrap(obj));
  }
  for (i = 0, len = LIFECYCLE_METHODS.length; i < len; i++) {
    fn = LIFECYCLE_METHODS[i];
    if (!(Utils.isFunction(obj[fn]))) {
      continue;
    }
    if (fn !== 'dispose' && ko.isObservable(obj)) {
      continue;
    }
    obj[fn]();
    break;
  }
};

ko.releaseKeys = function(obj) {
  var k, v;
  for (k in obj) {
    v = obj[k];
    if (!(!(k === '__released' || k === '__element') && ko.isReleasable(v))) {
      continue;
    }
    obj[k] = null;
    ko.release(v);
  }
};

ko.wasReleased = function(obj) {
  return obj.__released;
};
