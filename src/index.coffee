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
    return if Object.keys(node).some((test)-> test.indexOf('__ko__') is 0)
    ko.applyBindings(data, node)

  unbindDom: (node) -> ko.cleanNode(node)

  ###
  # knockout-es5 wrapper
  ###
  @custom_wrappers: new Map()
  @observe: (state, context={}) ->
    for key, value of state when not ko.isObservable(value)
      if Utils.isFunction(value)
        state[key] = ko.pureComputed(value)
        continue
      wrapper = null
      KOComponent.custom_wrappers.forEach (handler, key) ->
        return if wrapper
        wrapper = handler if value instanceof key
      continue unless wrapper
      state[key] = wrapper(value)
    Object.assign(context, state)
    ko.track(context, Object.keys(state))
  observe: (state, context=@) => KOComponent.observe(state, context)

  ###
  # knockout explicit memory safe computed for synchronizing values
  ###
  sync: (paths..., callback) =>
    comp = ko.computed =>
      args = for path in paths
        if ko.isObservable(path) then path()
        else
          resolved = @
          for part in path.split('.')
            break unless resolved = resolved[part]
          resolved
      ko.ignoreDependencies -> callback.apply(null, args)
    @addReleaseCallback -> comp.dispose()
