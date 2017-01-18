ko = require 'knockout'
require './extensions'
require './bindings'
require './preprocessor'

{Component, Utils} = require 'component-register'

module.exports = class KOComponent extends Component
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

  ###
  # element property change default handler
  ###
  onPropertyChange: (name, val) =>
    return @props[name] = val if Utils.isFunction(val)
    @props[name]?(val)

  bindDom: (node, data) -> ko.applyBindings(data, node)
  unbindDom: (node) -> ko.cleanNode(node)

  ###
  # To avoid top level assertions between comment tags we must add a container
  # current shortcoming of polyfill
  ###
  renderTemplate: (template, context={}) =>
    el = container = document.createElement('div')
    el.innerHTML = template
    if el.childNodes.length > 1
      el = document.createElement('div')
      el.appendChild(container)
    @bindDom(el.firstChild, context)
    return el.childNodes

  ###
  # knockout explicit memory safe computed for synchronizing values
  ###
  sync: (observables..., callback) =>
    comp = ko.computed ->
      args = []
      args.push(obsv()) for obsv in observables
      ko.ignoreDependencies -> callback.apply(null, args)
    @addReleaseCallback -> comp.dispose()
