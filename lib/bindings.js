var Registry, Utils, _getBindingAccessors, _nodeHasBindings, ko, original_update, ref;

ko = require('knockout');

ref = require('component-register'), Registry = ref.Registry, Utils = ref.Utils;

_getBindingAccessors = ko.bindingProvider.instance.getBindingAccessors;

ko.bindingProvider.instance.getBindingAccessors = function(node) {
  var bindings;
  bindings = _getBindingAccessors.apply(ko.bindingProvider.instance, arguments) || {};
  if (Registry[Utils.toComponentName(node != null ? node.tagName : void 0)]) {
    bindings.bindComponent = true;
  }
  return bindings;
};

_nodeHasBindings = ko.bindingProvider.instance.nodeHasBindings;

ko.bindingProvider.instance.nodeHasBindings = function(node) {
  return !!Registry[Utils.toComponentName(node != null ? node.tagName : void 0)] || _nodeHasBindings.apply(ko.bindingProvider.instance, arguments);
};

ko.bindingHandlers.bindComponent = {
  after: ['prop', 'attr', 'value'],
  init: function(element, value_accessor, all_bindings_accessor, view_model, binding_context) {
    setTimeout(function() {
      if (typeof element.boundCallback === "function") {
        element.boundCallback();
      }
      return ko.applyBindingsToDescendants(binding_context, element);
    }, 0);
    return {
      controlsDescendantBindings: true
    };
  }
};

ko.bindingHandlers.prop = {
  init: function(element, valueAccessor) {
    return setTimeout(function() {
      var i, k, len, props, v;
      props = element.__component_type.props;
      for (v = i = 0, len = props.length; i < len; v = ++i) {
        k = props[v];
        if (v.notify) {
          (function(k, v) {
            return ko.utils.registerEventHandler(element, v.event_name, function(event) {
              var obsv;
              if (event.target !== element) {
                return;
              }
              if (!((obsv = valueAccessor()[k]) && ko.isObservable(obsv))) {
                return;
              }
              return obsv(event.detail);
            });
          })(k, v);
        }
      }
      return ko.computed(function() {
        var ref1, value;
        if (element.__released) {
          return;
        }
        ref1 = valueAccessor();
        for (k in ref1) {
          v = ref1[k];
          if (!(k in props)) {
            continue;
          }
          value = ko.unwrap(v);
          if (value == null) {
            value = null;
          }
          if (element[k] === value && !Array.isArray(element[k])) {
            continue;
          }
          element[k] = value;
        }
      }, null, {
        disposeWhenNodeIsRemoved: element
      });
    }, 0);
  }
};

original_update = ko.bindingHandlers.attr.update;

ko.bindingHandlers.attr.update = function(element, value_accessor, all_bindings_accessor, view_model, binding_context) {
  var new_value_accessor;
  new_value_accessor = function() {
    var k, v, value;
    value = ko.unwrap(value_accessor());
    for (k in value) {
      v = value[k];
      if (!Utils.isString(v)) {
        value[k] = JSON.stringify(v);
      }
    }
    return value;
  };
  return original_update(element, new_value_accessor, all_bindings_accessor, view_model, binding_context);
};

ko.virtualElements.allowedBindings.inject = true;

ko.bindingHandlers.inject = {
  init: function(element, value_accessor, all_bindings_accessor, view_model, binding_context) {
    var nodes;
    if (!(nodes = value_accessor()(binding_context.$rawData, binding_context.$index()))) {
      return;
    }
    ko.virtualElements.setDomNodeChildren(element, nodes);
    return {
      controlsDescendantBindings: true
    };
  }
};

ko.virtualElements.allowedBindings.wrap = true;

ko.bindingHandlers.wrap = {
  init: function(element, value_accessor, all_bindings_accessor, view_model, binding_context) {
    var alias, context, obj;
    alias = all_bindings_accessor().as || '$data';
    context = binding_context.extend((
      obj = {},
      obj["" + alias] = ko.unwrap(value_accessor()),
      obj
    ));
    ko.applyBindingsToDescendants(context, element);
    return {
      controlsDescendantBindings: true
    };
  }
};
