ko = require 'knockout'

###
# Helpers
###
addDisposable = (source, subscriber) ->
  unless subscriber._disposables
    subscriber._disposables = []
    ogDispose = subscriber.dispose
    subscriber.dispose = ->
      dispose() for dispose in subscriber._disposables
      delete subscriber.source
      ogDispose?.apply(subscriber, arguments)
  subscriber._disposables.push(source.dispose.bind(source)) if source.dispose

###
# Custom functions to transform observable data
###
ko.subscribable.fn.map = (fn) ->
  oldValue = null
  obsv = ko.pureComputed(=>
    value = @()
    return if value is undefined
    return obsv?._latestValue if @equalityComparer(value, oldValue)
    ko.release(obsv?._latestValue) if oldValue
    oldValue = value
    fn(value)
  ).extend(notify: 'always')
  addDisposable(@, obsv)
  obsv.source = @source or @
  obsv

ko.subscribable.fn.arrayMap = (fn) ->
  oldValue = []
  obsv = ko.pureComputed(=>
    value = @()
    return if value is undefined
    mapped = value.map (test) ->
      return obsv?._latestValue[index] if (index = oldValue?.indexOf(test)) isnt -1
      fn(test)
    ko.release(to_release) if obsv?._latestValue and (to_release = obsv?._latestValue.filter((test) -> mapped.indexOf(test) is -1)).length
    oldValue = value[..]
    return mapped
  ).extend(notify: 'always')
  addDisposable(@, obsv)
  obsv.source = @source or @
  obsv

ko.subscribable.fn.filter = (fn) ->
  obsv = ko.observable().extend(notify: 'always')
  comp = ko.computed =>
    value = @()
    return if value is undefined or not fn(value)
    obsv(value)
  ogDispose = obsv.dispose
  obsv.dispose = ->
    comp.dispose()
    ogDispose?.apply(obsv, arguments)
  addDisposable(@, comp)
  obsv.source = @source or @
  obsv

ko.subscribable.fn.clone = ->
  obsv = ko.pureComputed => @()
  addDisposable(@, obsv)
  obsv.source = @source or @
  obsv

ko.subscribable.fn.pluck = (property) -> @map (obj) -> obj?[property]
ko.subscribable.fn.mapTo = (value) -> @map -> value

ko.subscribable.fn.scan = (fn, initial_value) ->
  obsv = ko.pureComputed(=>
    value = @()
    return initial_value if value is undefined
    return value unless memo = (obsv?._latestValue or initial_value)
    fn(memo, value)
  ).extend(notify: 'always')
  addDisposable(@, obsv)
  obsv.source = @source or @
  obsv

ko.subscribable.fn.debounce = (time) ->
  @extend({rateLimit: {timeout: time, method: 'notifyWhenChangesStop'}, notify: 'always'})

ko.subscribable.fn.throttle = (time) ->
  @extend({rateLimit: time, notify: 'always'})

ko.fromEvent = (element, name) ->
  obsv = ko.observable().extend({notify: 'always'})
  element.addEventListener(name, obsv)
  ogDispose = obsv.dispose
  obsv.dispose = =>
    element.removeEventListener(name, obsv)
    ogDispose?.apply(obsv, arguments)
  obsv