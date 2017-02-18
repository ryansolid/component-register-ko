ko = require 'knockout'
{Registry, Utils} = require 'component-register'

###
# these override the standard binding providers to autobind our components
###
_getBindingAccessors = ko.bindingProvider.instance.getBindingAccessors
ko.bindingProvider.instance.getBindingAccessors = (node) ->
  bindings = _getBindingAccessors.apply(ko.bindingProvider.instance, arguments) or {}
  if Registry[Utils.toComponentName(node?.tagName)]
    bindings.bindComponent = (-> true)
  else if node.hasAttribute?('data-root')
    bindings.stopBinding = (-> true)
  bindings.slot = (-> true) if node.nodeName is "SLOT" and node.hasAttribute('assigned')
  bindings

_nodeHasBindings = ko.bindingProvider.instance.nodeHasBindings
ko.bindingProvider.instance.nodeHasBindings = (node) ->
  return !!Registry[Utils.toComponentName(node?.tagName)] or (node.nodeName is 'SLOT' and node.hasAttribute('assigned')) or node.hasAttribute?('data-root') or _nodeHasBindings.apply(ko.bindingProvider.instance, arguments)

###
# main component binding
###
ko.bindingHandlers.bindComponent =
  after: ['prop', 'attr', 'value', 'checked']
  init: (element, value_accessor, all_bindings_accessor, view_model, binding_context) ->
    bind = ->
      element.boundCallback?()
      # set ref is present
      ref(element) if ref = all_bindings_accessor().ref
      if Utils.useShadowDOM
        ko.applyBindingsToDescendants(binding_context, element)
      else
        inner_context = new ko.bindingContext element.__component, null, null, (context) -> ko.utils.extend(context, {$outerContext: binding_context})
        ko.applyBindingsToDescendants(inner_context, element)

    if element.boundCallback? then bind()
    else setTimeout bind, 0
    return {controlsDescendantBindings: true}

###
# used to bind to element properties
###
ko.bindingHandlers.prop =
  init: (element, valueAccessor) ->
    bind = ->
      props = element.__component_type?.props or {}
      for k, v of props when v.notify
        do (k, v) -> ko.utils.registerEventHandler element, v.event_name, (event) ->
          return unless event.target is element
          value = ko.unwrap(valueAccessor())
          return unless (obsv = value[k] or value[v.attribute]) and ko.isObservable(obsv)
          new_val = event.detail
          new_val = new_val[..] if Array.isArray(new_val)
          obsv(new_val)
      ko.computed ->
        for k, v of ko.unwrap(valueAccessor())
          value = ko.unwrap(v)
          value = null unless value?
          if key = element.lookupProp?(k)
            if Array.isArray(value)
              continue if Array.isArray(element[key]) and not Utils.arrayDiff(value, element[key])
              element[key] = value[..]
            else
              continue if element[key] is value
              element[key] = value
          # attribute bind
          else
            if value
              value = JSON.stringify(value) if !Utils.isString(value)
              element.setAttribute(k, value)
            else element.removeAttribute(k)
        return
      , null, {disposeWhenNodeIsRemoved: element}
    if element.boundCallback? then bind()
    else setTimeout bind, 0

###
# Slot binding to handle context change when not using shadowdom
###
ko.bindingHandlers.slot =
  init: (element, value_accessor, all_bindings_accessor, view_model, binding_context) ->
    setTimeout ->
      ko.applyBindingsToDescendants(binding_context.$outerContext, element)
    , 0
    return {controlsDescendantBindings: true}

###
# stops binding
###
ko.bindingHandlers.stopBinding =
  init: (element) -> return {controlsDescendantBindings: true}

###
# Grabs element reference for non-components
###
ko.bindingHandlers.ref =
  after: ['attr', 'value', 'checked']
  init: (element, value_accessor, all_bindings_accessor) ->
    return if all_bindings_accessor().bindComponent
    value_accessor()(element)

###
# sets the style.cssText property of an element, removes timing issue with binding to attribute
###
ko.bindingHandlers.csstext =
  update: (element, value_accessor) ->
    element.style.cssText = ko.unwrap(value_accessor())

###
# used to insert html element nodes
###
ko.virtualElements.allowedBindings.inject = true
ko.bindingHandlers.inject =
  init: (element, value_accessor, all_bindings_accessor, view_model, binding_context) ->
    return unless nodes = value_accessor()(binding_context.$rawData, binding_context.$index())
    ko.virtualElements.setDomNodeChildren(element, nodes)
    return {controlsDescendantBindings: true}

isFalsy = (data) ->
  return true unless data
  return true if Utils.isObject(data) and 'length' of data and not data.length
  false

###
# similar to with but doesn't redraw all child nodes
###
ko.virtualElements.allowedBindings.use = true
ko.bindingHandlers.use =
  init: (element, value_accessor, all_bindings_accessor, view_model, binding_context) ->
    template_nodes = ko.utils.cloneNodes(ko.virtualElements.childNodes(element), true)
    needs_bind = true
    obsv = ko.observable()
    ko.computed ->
      value = value_accessor()
      data = ko.unwrap(value)
      unless isFalsy(data)
        obsv(data)
        if needs_bind
          ko.virtualElements.setDomNodeChildren(element, ko.utils.cloneNodes(template_nodes));
          context = binding_context.createChildContext(obsv)
          ko.applyBindingsToDescendants(context, element)
          needs_bind = false
      else
        ko.virtualElements.emptyNode(element);
        needs_bind = true
    , null, {disposeWhenNodeIsRemoved: element}
    return {controlsDescendantBindings: true}

###
# update if/ifnot/with to check array length as falsy condition
###
makeWithIfBinding = (bindingKey, isWith, isNot, makeContextCallback) ->
  ko.bindingHandlers[bindingKey] = 'init': (element, valueAccessor, allBindings, viewModel, bindingContext) ->
    didDisplayOnLastUpdate = undefined
    savedNodes = undefined
    ko.computed (->
      rawValue = valueAccessor()
      dataValue = ko.utils.unwrapObservable(rawValue)
      shouldDisplay = !isNot != isFalsy(dataValue)
      isFirstRender = !savedNodes
      needsRefresh = isFirstRender or isWith or shouldDisplay != didDisplayOnLastUpdate
      if needsRefresh
        # Save a copy of the inner nodes on the initial update, but only if we have dependencies.
        if isFirstRender and ko.computedContext.getDependenciesCount()
          savedNodes = ko.utils.cloneNodes(ko.virtualElements.childNodes(element), true)
        if shouldDisplay
          if !isFirstRender
            ko.virtualElements.setDomNodeChildren element, ko.utils.cloneNodes(savedNodes)
          ko.applyBindingsToDescendants (if makeContextCallback then makeContextCallback(bindingContext, rawValue) else bindingContext), element
        else
          ko.virtualElements.emptyNode element
        didDisplayOnLastUpdate = shouldDisplay
      return
    ), null, disposeWhenNodeIsRemoved: element
    { 'controlsDescendantBindings': true }
  ko.expressionRewriting.bindingRewriteValidators[bindingKey] = false
  # Can't rewrite control flow bindings
  ko.virtualElements.allowedBindings[bindingKey] = true
  return

makeWithIfBinding('if')
makeWithIfBinding('ifnot', false, true)
makeWithIfBinding 'with', true, false, (bindingContext, dataValue) ->
  bindingContext.createStaticChildContext dataValue