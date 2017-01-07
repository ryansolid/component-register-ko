ko = require 'knockout'
{Registry, Utils} = require 'component-register'

# these override the standard binding providers to autobind our components
_getBindingAccessors = ko.bindingProvider.instance.getBindingAccessors
ko.bindingProvider.instance.getBindingAccessors = (node) ->
  bindings = _getBindingAccessors.apply(ko.bindingProvider.instance, arguments) or {}
  bindings.bindComponent = true if Registry[Utils.toComponentName(node?.tagName)]
  bindings

_nodeHasBindings = ko.bindingProvider.instance.nodeHasBindings
ko.bindingProvider.instance.nodeHasBindings = (node) ->
  return !!Registry[Utils.toComponentName(node?.tagName)] or _nodeHasBindings.apply(ko.bindingProvider.instance, arguments)

# main component binding
ko.bindingHandlers.bindComponent =
  after: ['prop', 'attr', 'value']
  init: (element, value_accessor, all_bindings_accessor, view_model, binding_context) ->
    setTimeout ->
      element.boundCallback?()
      ko.applyBindingsToDescendants(binding_context, element)
    , 0
    return {controlsDescendantBindings: true}

# used to bind to element properties
ko.bindingHandlers.prop =
  init: (element, valueAccessor) ->
    setTimeout ->
      props = element.__component_type.props
      for k, v in props when v.notify
        do (k, v) -> ko.utils.registerEventHandler element, v.event_name, (event) ->
          return unless event.target is element
          return unless (obsv = valueAccessor()[k]) and ko.isObservable(obsv)
          obsv(event.detail)
      ko.computed ->
        return if element.__released
        for k, v of valueAccessor() when k of props
          value = ko.unwrap(v)
          value = null unless value?
          # always update arrays, consider better way. Cloning arrays and comparing values?
          continue if element[k] is value and not Array.isArray(element[k])
          element[k] = value
        return
      , null, {disposeWhenNodeIsRemoved: element}
    , 0

# Update attr binding to serialize to JSON
original_update = ko.bindingHandlers.attr.update
ko.bindingHandlers.attr.update = (element, value_accessor, all_bindings_accessor, view_model, binding_context) ->
  new_value_accessor = ->
    value = ko.unwrap(value_accessor());
    value[k] = JSON.stringify(val) for k, v of value when (val = ko.unwrap(v)) and !Utils.isString(val)
    value
  original_update(element, new_value_accessor, all_bindings_accessor, view_model, binding_context)

# used to insert html element nodes
ko.virtualElements.allowedBindings.inject = true
ko.bindingHandlers.inject =
  init: (element, value_accessor, all_bindings_accessor, view_model, binding_context) ->
    return unless nodes = value_accessor()(binding_context.$rawData, binding_context.$index())
    ko.virtualElements.setDomNodeChildren(element, nodes)
    return {controlsDescendantBindings: true}

# similar to with but doesn't redraw all nodes
ko.virtualElements.allowedBindings.use = true
ko.bindingHandlers.use =
  init: (element, value_accessor, all_bindings_accessor, view_model, binding_context) ->
    template_nodes = ko.utils.cloneNodes(ko.virtualElements.childNodes(element), true)
    needs_bind = true
    obsv = ko.observable()
    ko.computed(->
      value = value_accessor()
      data = ko.unwrap(value)
      if data
        obsv(data)
        if needs_bind
          ko.virtualElements.setDomNodeChildren(element, ko.utils.cloneNodes(template_nodes));
          extend = all_bindings_accessor().extend or {}
          context = binding_context.createChildContext obsv, null, (context) -> ko.utils.extend(context, extend)
          ko.applyBindingsToDescendants(context, element)
          needs_bind = false
      else
        ko.virtualElements.emptyNode(element);
        needs_bind = true
    , null, {disposeWhenNodeIsRemoved: element}).extend({notify: 'always'})
    return {controlsDescendantBindings: true}