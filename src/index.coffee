ko = require 'knockout'
require 'knockout-es5'
require './extensions'
require './bindings'

{Component, Utils} = require 'component-register'

module.exports = class KOComponent extends Component
  constructor: (element, props) ->
    super
    @props = {}
    tracking_keys = []
    for key, prop of props then do (key, prop) =>
      return @props[key] = element[key] if Utils.isFunction(element[key])
      tracking_keys.push(key)
      if Array.isArray(element[key])
        @props[key] = ko.observableArray(element[key])
      else @props[key] = ko.observable(element[key])
      @props[key].subscribe (v) =>
        return if @__released
        @setProperty(key, v)
    ko.track(@props, tracking_keys) if tracking_keys.length

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
  # knockout-es5 wrapper
  ###
  @custom_wrappers: new Map()
  observe: (fields) =>
    for key in fields when not ko.isObservable(@[key])
      unless @[key]?
        @[key] = null
        continue
      if Utils.isFunction(@[key])
        @[key] = ko.pureComputed(@[key])
        continue
      it = KOComponent.custom_wrappers.keys()
      while (obj = it.next()) and not obj.done
        break if @[key] instanceof obj.value
      continue unless obj?.value
      wrapper = KOComponent.custom_wrappers.get(obj.value)
      @[key] = wrapper(@[key])
    ko.track(@, fields)

  ###
  # knockout explicit memory safe computed for synchronizing values
  ###
  sync: (paths..., callback) =>
    comp = ko.computed =>
      args = for path in paths
        resolved = @
        for part in path.split('.')
          break unless resolved = resolved[part]
        resolved
      ko.ignoreDependencies -> callback.apply(null, args)
    @addReleaseCallback -> comp.dispose()
