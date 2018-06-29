import ko from 'knockout'
import './extensions'
import './bindings'

import { register as coreRegister, compose, createMixin, Utils } from 'component-register'
import { withEvents, withTimer, withShadyCSS } from 'component-register-extensions'

export withKO = (ComponentType) ->
  withShadyCSS withEvents withTimer (options) ->
    { element, props: defaultProps, timer, events } = options
    props = {}
    for key, prop of defaultProps then do (key, prop) =>
      return props[key] = element[key] if Utils.isFunction(element[key])
      if Array.isArray(element[key])
        props[key] = ko.observableArray(element[key])
      else props[key] = ko.observable(element[key])
      props[key].subscribe (v) -> element.setProperty(key, v)

    element.addPropertyChangedCallback (name, val) ->
      return props[name] = val if Utils.isFunction(val)
      props[name]?(val)

    # create
    comp = new ComponentType(element, props, { timer, events })
    element.addReleaseCallback ->
      ko.releaseKeys(comp)
      ko.cleanNode(element)

    if styles = ComponentType.styles
      script = document.createElement('style')
      script.textContent = styles
      element.renderRoot().appendChild(script)

    if template = ComponentType.template
      el = document.createElement('div')
      el.innerHTML = template
      # support webcomponent template polyfill for IE
      HTMLTemplateElement.bootstrap?(el)
      unless Object.keys(el).some((test)-> test.indexOf('__ko__') is 0)
        ko.applyBindings(comp, el)

      nodes = Array::slice.call(el.childNodes)
      element.renderRoot().appendChild(node) while node = nodes?.shift()
      comp.onMounted?(element)

    comp

export register = (ComponentType) ->
  compose(
    coreRegister(ComponentType.tag, {props: ComponentType.props})
    withKO
  )(ComponentType)

export class Component
  constructor: (@element, @props, mixins) ->
    # mixin
    for name, mixin of mixins
      for attr of mixin then do (name, attr) =>
        Object.defineProperty @, attr, {
          get: -> mixins[name][attr]
        }

  ###
  # knockout explicit memory safe computed for synchronizing values
  ###
  sync: (observables..., callback) =>
    comp = ko.computed ->
      args = []
      args.push(obsv()) for obsv in observables
      ko.ignoreDependencies -> callback.apply(null, args)
    @element.addReleaseCallback -> comp.dispose()