import ko from 'knockout'
import { toAttribute, toProperty, isObject } from 'component-register'
import { requestCSSId } from 'component-register-extensions'

BOOLEAN_ATTR =  new RegExp('^(?:disabled|checked|readonly|required|allowfullscreen|auto(?:focus|play)' +
  '|compact|controls|default|formnovalidate|hidden|ismap|itemscope|loop' +
  '|multiple|muted|no(?:resize|shade|validate|wrap)?|open|reversed|seamless' +
  '|selected|sortable|truespeed|typemustmatch)$')

###
# used to bind to element properties
###
ko.bindingHandlers.prop =
  init: (element, valueAccessor) ->
    ko.utils.registerEventHandler element, 'propertychange', (event) ->
      return unless event.target is element
      value = ko.unwrap(valueAccessor())
      name = event.detail.name
      return unless (obsv = value[name] or value[toAttribute(name)]) and ko.isObservable(obsv)
      new_val = event.detail.value
      new_val = new_val[..] if Array.isArray(new_val)
      obsv(new_val)
    ko.computed ->
      for k, v of ko.unwrap(valueAccessor())
        value = ko.unwrap(v)
        value = null unless value?
        if isObject(value) or k in ['value', 'checked']
          key = element.lookupProp?(k) or toProperty(k)
          element[key] = value
          continue
        # attribute bind
        key = toAttribute(k)
        if value
          value = JSON.stringify(value) unless typeof value is 'string'
          continue if element.getAttribute(key) is value
          element.setAttribute(key, value)
          continue
        if element.hasAttribute(key)
          if BOOLEAN_ATTR.test(key)
            element.removeAttribute(key)
          else element.setAttribute(key, if value? then value else '')
        else element[element.lookupProp?(k) or toProperty(k)] = value
      return
    , null, {disposeWhenNodeIsRemoved: element}

###
# injects HTML Template Element
###
ko.virtualElements.allowedBindings.inject = true
ko.bindingHandlers.inject =
  init: -> return {controlsDescendantBindings: true}
  update: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    return unless template = ko.unwrap(valueAccessor())
    el = document.createElement('div')
    el.appendChild(document.importNode(template.content, true))
    ko.applyBindingsToDescendants(bindingContext, el)
    nodes = Array::slice.call(el.childNodes)
    ko.virtualElements.emptyNode(element)
    ko.virtualElements.setDomNodeChildren(element, nodes)

###
# portal HTML Template Element
###
ko.virtualElements.allowedBindings.portal = true
ko.bindingHandlers.portal =
  init:  (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    mountEl = document.body
    name = ko.unwrap(valueAccessor())
    el = document.createElement('div')
    el.host = bindingContext.$root.element
    root = el.attachShadow({mode: 'open'})
    el.appendChild(child) while child = ko.virtualElements.firstChild(element)
    ko.applyBindingsToDescendants(bindingContext, el)

    el._cssId = requestCSSId(bindingContext.$root.element.nodeName + '-' + name)
    Promise.resolve().then ->
      root.appendChild(child) while child = el.firstChild
    mountEl.appendChild(el)

    bindingContext.$root.element.addReleaseCallback ->
      delete el.host
      ko.removeNode(el)

    return {controlsDescendantBindings: true}

###
# Grabs element reference for non-components
###
ko.bindingHandlers.ref =
  after: ['prop', 'attr', 'value', 'checked', 'bindComponent']
  init: (element, valueAccessor) ->
    valueAccessor()(element)

###
# sets the style.cssText property of an element, removes timing issue with binding to attribute
###
ko.bindingHandlers.csstext =
  update: (element, valueAccessor) ->
    element.style.cssText = ko.unwrap(valueAccessor())

###
# checked binding to hanlde indeterminate
###
ko.bindingHandlers.tristate =
  init: (element, valueAccessor, allBindings) ->
    obsv = valueAccessor()
    ko.utils.registerEventHandler element, 'click', (e) ->
      if ko.unwrap(obsv) is false then obsv?(true) else obsv?(false)

  update: (element, valueAccessor) ->
    switch ko.unwrap(valueAccessor())
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
  return true if isObject(data) and 'length' of data and not data.length
  false

###
# similar to with but doesn't redraw all child nodes
###
ko.virtualElements.allowedBindings.use = true
ko.bindingHandlers.use =
  init: (element, valueAccessor, allBindingsAccessor, viewModel, bindingContext) ->
    templateNodes = ko.utils.cloneNodes(ko.virtualElements.childNodes(element), true)
    needsBind = true
    obsv = ko.observable()
    ko.computed ->
      value = valueAccessor()
      data = ko.unwrap(value)
      unless isFalsy(data)
        obsv(data)
        if needsBind
          ko.virtualElements.setDomNodeChildren(element, ko.utils.cloneNodes(templateNodes));
          context = bindingContext.createChildContext(obsv)
          ko.applyBindingsToDescendants(context, element)
          needsBind = false
      else
        ko.virtualElements.emptyNode(element);
        needsBind = true
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