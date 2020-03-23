import ko from 'knockout'
import { isFunction } from 'component-register'
LIFECYCLE_METHODS = ['dispose']

###
# Memory subscription cleanup
###
ko.isReleasable = (obj, depth=0) ->
  return false if (not obj or (obj isnt Object(obj))) or obj.__released # must be an object and not already released
  return true if ko.isObservable(obj) # a known type that is releasable
  return false if isFunction(obj) or obj instanceof Element # a known type that is not releasable
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
  for fn in LIFECYCLE_METHODS when isFunction(obj[fn])
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