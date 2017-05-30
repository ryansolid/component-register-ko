ko = require 'knockout'

###
# Helpers
###
addDisposable = (source, subscriber) ->
  unless subscriber._disposables
    subscriber._disposables = []
    og_dispose = subscriber.dispose
    subscriber.dispose = ->
      dispose() for dispose in subscriber._disposables
      og_dispose?.apply(subscriber, arguments)
  subscriber._disposables.push(source.dispose) if source.dispose

###
# Custom functions to transform observable data
###
ko.subscribable.fn.map = (fn) ->
  old_value = null
  obsv = ko.pureComputed(=>
    value = @()
    return if value is undefined
    return obsv?._latestValue if value is old_value
    ko.release(obsv?._latestValue) if old_value
    old_value = value
    ko.ignoreDependencies -> fn(value)
  ).extend(notify: 'always')
  addDisposable(@, obsv)
  obsv

ko.subscribable.fn.arrayMap = (fn) ->
  old_value = []
  obsv = ko.pureComputed(=>
    value = @()
    return if value is undefined
    mapped = value.map (test) ->
      return obsv?._latestValue[index] if (index = old_value?.indexOf(test)) isnt -1
      ko.ignoreDependencies -> fn(test)
    ko.release(to_release) if obsv?._latestValue and (to_release = obsv?._latestValue.filter((test) -> mapped.indexOf(test) is -1)).length
    old_value = value
    return mapped
  ).extend(notify: 'always')
  addDisposable(@, obsv)
  obsv

ko.subscribable.fn.filter = (fn) ->
  obsv = ko.observable().extend(notify: 'always')
  comp = ko.computed =>
    value = @()
    return if value is undefined or not fn(value)
    obsv(value)
  og_dispose = obsv.dispose
  obsv.dispose = ->
    comp.dispose()
    og_dispose?.apply(obsv, arguments)
  addDisposable(@, comp)
  obsv

ko.subscribable.fn.pluck = (property) -> @map (obj) -> obj?[property]

ko.subscribable.fn.scan = (fn, initial_value) ->
  obsv = ko.pureComputed(=>
    value = @()
    return initial_value if value is undefined
    return value unless memo = (obsv?._latestValue or initial_value)
    fn(memo, value)
  ).extend(notify: 'always')
  addDisposable(@, obsv)
  obsv

ko.subscribable.fn.debounce = (time) ->
  @extend({rateLimit: {timeout: time, method: 'notifyWhenChangesStop'}, notify: 'always'})

ko.subscribable.fn.throttle = (time) ->
  @extend({rateLimit: time, notify: 'always'})

ko.fromEvent = (element, name) ->
  obsv = ko.observable().extend({notify: 'always'})
  element.addEventListener(name, obsv)
  og_dispose = obsv.dispose
  obsv.dispose = =>
    element.removeEventListener(name, obsv)
    og_dispose?.apply(obsv, arguments)
  obsv