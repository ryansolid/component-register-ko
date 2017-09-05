ko = require 'knockout'
require './extensions'
require './bindings'

{Component, Utils} = require 'component-register'
CSSPolyfill = require 'component-register/lib/css_polyfill'

module.exports = class KOComponent extends Component
  @exclude_tags = []
  constructor: (element, props) ->
    super
    @props = {}
    for key, prop of props then do (key, prop) =>
      return @props[key] = element[key] if Utils.isFunction(element[key])
      if Array.isArray(element[key])
        @props[key] = ko.observableArray(element[key])
      else @props[key] = ko.observable(element[key])
      @props[key].subscribe (v) =>
        return if @__released
        @setProperty(key, v)

    @addReleaseCallback => ko.releaseKeys(@)

  onRender: (element) ->
    return unless template = @constructor.template
    template = CSSPolyfill.html(template, @css_id) if @css_id
    el = document.createElement('div')
    el.innerHTML = template
    # support webcomponent template polyfill for IE
    HTMLTemplateElement.bootstrap?(el)
    unless Object.keys(el).some((test)-> test.indexOf('__ko__') is 0)
      ko.applyBindings(@, el)
    @addReleaseCallback -> ko.cleanNode(element)
    nodes = Array::slice.call(el.childNodes)
    element.shadowRoot.appendChild(node) while node = nodes?.shift()

  ###
  # element property change default handler
  ###
  onPropertyChange: (name, val) =>
    return @props[name] = val if Utils.isFunction(val)
    @props[name]?(val)

  ###
  # knockout explicit memory safe computed for synchronizing values
  ###
  sync: (observables..., callback) =>
    comp = ko.computed ->
      args = []
      args.push(obsv()) for obsv in observables
      ko.ignoreDependencies -> callback.apply(null, args)
    @addReleaseCallback -> comp.dispose()

###
# these override the standard binding providers to autobind our components
###
_getBindingAccessors = ko.bindingProvider.instance.getBindingAccessors
ko.bindingProvider.instance.getBindingAccessors = (node) ->
  bindings = _getBindingAccessors.apply(ko.bindingProvider.instance, arguments) or {}
  if node.nodeName in KOComponent.exclude_tags
    bindings.stopBinding = (-> true)
  bindings

_nodeHasBindings = ko.bindingProvider.instance.nodeHasBindings
ko.bindingProvider.instance.nodeHasBindings = (node) ->
  return (node.nodeName in KOComponent.exclude_tags) or _nodeHasBindings.apply(ko.bindingProvider.instance, arguments)
