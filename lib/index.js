var Component, KOComponent, Utils, ko, ref,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  slice = [].slice;

ko = require('knockout');

require('./extensions');

require('./bindings');

require('./preprocessor');

ref = require('component-register'), Component = ref.Component, Utils = ref.Utils;

module.exports = KOComponent = (function(superClass) {
  extend(KOComponent, superClass);

  function KOComponent(element, props) {
    this.sync = bind(this.sync, this);
    this.renderTemplate = bind(this.renderTemplate, this);
    this.onPropertyChange = bind(this.onPropertyChange, this);
    var fn, key, prop;
    KOComponent.__super__.constructor.apply(this, arguments);
    this.props = {};
    fn = (function(_this) {
      return function(key, prop) {
        if (Utils.isFunction(element[key])) {
          return _this.props[key] = element[key];
        }
        if (Array.isArray(element[key])) {
          _this.props[key] = ko.observableArray(element[key]);
        } else {
          _this.props[key] = ko.observable(element[key]);
        }
        return _this.props[key].subscribe(function(v) {
          if (_this.__released) {
            return;
          }
          return _this.setProperty(key, v);
        });
      };
    })(this);
    for (key in props) {
      prop = props[key];
      fn(key, prop);
    }
    this.addReleaseCallback((function(_this) {
      return function() {
        return ko.releaseKeys(_this);
      };
    })(this));
  }

  KOComponent.prototype.onPropertyChange = function(name, val) {
    var base;
    if (Utils.isFunction(val)) {
      return this.props[name] = val;
    }
    return typeof (base = this.props)[name] === "function" ? base[name](val) : void 0;
  };

  KOComponent.prototype.bindDom = function(node, data) {
    return ko.applyBindings(data, node);
  };

  KOComponent.prototype.unbindDom = function(node) {
    return ko.cleanNode(node);
  };

  KOComponent.prototype.renderTemplate = function(template, context) {
    var container, el;
    if (context == null) {
      context = {};
    }
    el = container = document.createElement('div');
    el.innerHTML = template;
    if (el.childNodes.length > 1) {
      el = document.createElement('div');
      el.appendChild(container);
    }
    this.bindDom(container, context);
    return el.childNodes;
  };

  KOComponent.prototype.sync = function() {
    var callback, comp, i, observables;
    observables = 2 <= arguments.length ? slice.call(arguments, 0, i = arguments.length - 1) : (i = 0, []), callback = arguments[i++];
    comp = ko.computed(function() {
      var args, j, len, obsv;
      args = [];
      for (j = 0, len = observables.length; j < len; j++) {
        obsv = observables[j];
        args.push(obsv());
      }
      return ko.ignoreDependencies(function() {
        return callback.apply(null, args);
      });
    });
    return this.addReleaseCallback(function() {
      return comp.dispose();
    });
  };

  return KOComponent;

})(Component);
