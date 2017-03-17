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
  onPropertyChange: (name, val) => @props[name] = val

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
  bind: (context, field) =>
    if arguments.length is 1
      field = context
      context = @
    ko.getObservable(context, field)
  @observe: (context, state) =>
    for key, value of state when not ko.isObservable(value)
      if Utils.isFunction(value)
        state[key] = ko.pureComputed(value)
        continue
      it = KOComponent.custom_wrappers.keys()
      while (obj = it.next()) and not obj.done
        break if value instanceof obj.value
      continue unless obj?.value
      wrapper = KOComponent.custom_wrappers.get(obj.value)
      state[key] = wrapper(value)
    Object.assign(context, state)
    ko.track(context, Object.keys(state))
  observe: (state) => KOComponent.observe(@, state)

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
