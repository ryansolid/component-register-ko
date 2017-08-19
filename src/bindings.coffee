ko = require 'knockout'
{Registry, Utils} = require 'component-register'

BOOLEAN_ATTR =  new RegExp('^(?:disabled|checked|readonly|required|allowfullscreen|auto(?:focus|play)' +
  '|compact|controls|default|formnovalidate|hidden|ismap|itemscope|loop' +
  '|multiple|muted|no(?:resize|shade|validate|wrap)?|open|reversed|seamless' +
  '|selected|sortable|truespeed|typemustmatch)$')

###
# these override the standard binding providers to autobind our components
###
_getBindingAccessors = ko.bindingProvider.instance.getBindingAccessors
ko.bindingProvider.instance.getBindingAccessors = (node) ->
  bindings = _getBindingAccessors.apply(ko.bindingProvider.instance, arguments) or {}
  if Registry[Utils.toComponentName(node?.tagName)]
    bindings.bindComponent = (-> true)
  else if node.nodeName in Utils.excludeTags
    bindings.stopBinding = (-> true)
  else if node.nodeName is "SLOT" and node.hasAttribute('assigned')
    bindings.slot = (-> true)
  bindings

_nodeHasBindings = ko.bindingProvider.instance.nodeHasBindings
ko.bindingProvider.instance.nodeHasBindings = (node) ->
  return !!Registry[Utils.toComponentName(node?.tagName)] or (node.nodeName is 'SLOT' and node.hasAttribute('assigned')) or node.nodeName in Utils.excludeTags or _nodeHasBindings.apply(ko.bindingProvider.instance, arguments)

###
# main component binding
###
ko.bindingHandlers.bindComponent =
  after: ['prop', 'attr', 'value', 'checked']
  init: (element, value_accessor, all_bindings_accessor, view_model, binding_context) ->
    Utils.scheduleMicroTask ->
      return if element.__released
      try
        element.boundCallback()
      catch err
        console.error err

###
# used to bind to element properties
###
ko.bindingHandlers.prop =
  init: (element, valueAccessor) ->
    ko.utils.registerEventHandler element, 'propertychange', (event) ->
      return unless event.target is element
      value = ko.unwrap(valueAccessor())
      name = event.detail.name
      return unless (obsv = value[name] or value[Utils.toAttribute(name)]) and ko.isObservable(obsv)
      new_val = event.detail.value
      new_val = new_val[..] if Array.isArray(new_val)
      obsv(new_val)
    ko.computed ->
      for k, v of ko.unwrap(valueAccessor())
        value = ko.unwrap(v)
        value = null unless value?
        if Utils.isObject(value)
          key = Utils.toProperty(k)
          element[key] = value
          continue
        # attribute bind
        key = Utils.toAttribute(k)
        if value
          value = JSON.stringify(value) if !Utils.isString(value)
          continue if element.getAttribute(key) is value
          element.setAttribute(key, value)
          continue
        if element.hasAttribute(key)
          if BOOLEAN_ATTR.test(key)
            element.removeAttribute(key)
          else element.setAttribute(key, if value? then value else '')
        else element[Utils.toProperty(k)] = value
      return
    , null, {disposeWhenNodeIsRemoved: element}

###
# stops binding
###
ko.bindingHandlers.stopBinding =
  init: (element) -> return {controlsDescendantBindings: true}

###
# Grabs element reference for non-components
###
ko.bindingHandlers.ref =
  after: ['prop', 'attr', 'value', 'checked', 'bindComponent']
  init: (element, value_accessor, all_bindings_accessor) ->
    value_accessor()(element)

###
# sets the style.cssText property of an element, removes timing issue with binding to attribute
###
ko.bindingHandlers.csstext =
  update: (element, value_accessor) ->
    element.style.cssText = ko.unwrap(value_accessor())

###
# checked binding to hanlde indeterminate
###
ko.bindingHandlers.tristate =
  init: (element, value_accessor, allBindings) ->
    obsv = value_accessor()
    ko.utils.registerEventHandler element, 'click', (e) ->
      if ko.unwrap(obsv) is false then obsv?(true) else obsv?(false)

  update: (element, value_accessor) ->
    switch ko.unwrap(value_accessor())
      when true
        element.checked = true
        element.indeterminate = false
      when false
        element.checked = false
        element.indeterminate = false
      else
        element.checked = false
        element.indeterminate = true

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
      return
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