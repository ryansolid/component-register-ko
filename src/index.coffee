ko = require 'knockout'
require './extensions'
require './bindings'

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

  bindDom: (node, data) =>
    return if @_dataFor(node)
    ko.applyBindings(data, node)

  unbindDom: (node) -> ko.cleanNode(node)

  _dataFor: (node) =>
    return true if Object.keys(node).some((test)-> test.indexOf('__ko__') is 0)
    return false if not node.parentNode or node.parentNode?.nodeName in Utils.excludeTags
    @_dataFor(node.parentNode)

  ###
  # knockout explicit memory safe computed for synchronizing values
  ###
  sync: (observables..., callback) =>
    comp = ko.computed ->
      args = []
      args.push(obsv()) for obsv in observables
      ko.ignoreDependencies -> callback.apply(null, args)
    @addReleaseCallback -> comp.dispose()
