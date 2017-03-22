ko = require 'knockout'
{Utils} = require 'component-register'
LIFECYCLE_METHODS = ['dispose']

###
# Patch ko to consider nodes connected to shadowRoots are still connected to document
###
orig_attached = ko.utils.domNodeIsAttachedToDocument
ko.utils.domNodeIsAttachedToDocument = (node) ->
  return true if node.isConnected or orig_attached.call(@, node)
  return false unless Utils.useShadowDOM
  null while (node = node.parentNode or node.host) and node isnt document.documentElement
  node is document.documentElement

###
# Memory subscription cleanup
###
ko.isReleasable = (obj, depth=0) ->
  return false if (not obj or (obj isnt Object(obj))) or obj.__released # must be an object and not already released
  return true if ko.isObservable(obj) # a known type that is releasable
  return false if Utils.isFunction(obj) or obj instanceof Element # a known type that is not releasable
  return true for method in LIFECYCLE_METHODS when typeof(obj[method]) is 'function' # a releasable signature
  return false if depth > 0 # max depth check for ViewModel inside of ViewModel
  return true for key, value of obj when ko.isReleasable(value, depth+1)
  return false

ko.release = (obj) ->
  return unless ko.isReleasable(obj)
  obj.__released = true
  if Array.isArray(obj)
    while obj.length
      ko.release(obj.shift())
    return
  ko.release(ko.unwrap(obj)) if ko.isObservable(obj) and not ko.isComputed(obj)
  for fn in LIFECYCLE_METHODS when Utils.isFunction(obj[fn])
    continue if fn isnt 'dispose' and ko.isObservable(obj)
    obj[fn]()
    break
  return

ko.releaseKeys = (obj) ->
  for k, v of obj when not (k in ['__released', 'element']) and ko.isReleasable(v)
    obj[k] = null unless k is 'props'
    ko.release(v)
  return

ko.wasReleased = (obj) -> obj.__released

###
# Memory safe mapping function
###
ko.observable.fn.map = (options) ->
  options = {map: options} if Utils.isFunction(options)
  mapped = ko.pureComputed =>
    value = if options.property then @()?[options.property] else @()
    unless value
      ko.release(mapped.peek()) if mapped?.peek()
      return
    old_value = mapped?.peek()?._value
    if Array.isArray(value)
      values = value
      values = values.filter(options.filter) if options.filter
      values = values.sort(options.comparator) if options.comparator
      if options.map
        values = values.map (test) ->
          return mapped_value if mapped_value = mapped?.peek()?.find (vm) -> vm._value is test
          mapped_value = ko.ignoreDependencies => options.map(test)
          mapped_value._value = test
          return mapped_value
      ko.release(to_release) if mapped?.peek() and (to_release = mapped.peek().filter((test) -> values.indexOf(test) is -1)).length
      return values
    else
      if old_value
        return mapped.peek() if value is old_value
        ko.release(mapped.peek())
      mapped_value = ko.ignoreDependencies => options.map(value)
      mapped_value._value = value
      return mapped_value

  mapped.source = @
  og_dispose = mapped.dispose
  mapped.dispose = ->
    ko.release(@peek())
    og_dispose.call(@)
  mapped