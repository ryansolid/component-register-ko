ko = require 'knockout'
{Registry, Utils} = require 'component-register'

###
# Based on knockout.punches and altered to handle prop binding
# Currently supports attr, prop, and text bindings using { } syntax.
# value, css(as class), event(as on*), checked, and ref bindings are also pushed to attributes
###

parseInterpolationMarkup = (textToParse, outerTextCallback, expressionCallback) ->
  outerMatch = textToParse.match(/^([\s\S]*?)\{([\s\S]*)}([\s\S]*)$/)

  innerParse = (text) ->
    innerMatch = text.match(/^([\s\S]*)}([\s\S]*?)\{([\s\S]*)$/)
    if innerMatch
      innerParse innerMatch[1]
      outerTextCallback innerMatch[2]
      expressionCallback innerMatch[3]
    else
      expressionCallback text

  if outerMatch
    outerTextCallback outerMatch[1]
    innerParse outerMatch[2]
    outerTextCallback outerMatch[3]

trim = (string) ->
  if string == null then '' else if string.trim then string.trim() else string.toString().replace(/^[\s\xa0]+|[\s\xa0]+$/g, '')

wrapExpression = (expressionText, node) ->
  ownerDocument = if node then node.ownerDocument else document
  result = []
  result.push ownerDocument.createComment('ko ' + 'text: ' + trim(expressionText))
  result.push ownerDocument.createComment('/ko')
  result

#TODO: find better way to find handlebar-less object notation, not or statement
isObjectNotation = (str) ->
  return false if str[0] is '{'
  c = str.length - str.replace(/:/g, '').length
  q = str.length - str.replace(/\?/g, '').length
  c > 0 and c > q

ko.bindingProvider.instance.preprocessNode = (node) ->
  if node.nodeType == 1 and node.attributes.length
    data_bind_attribute = node.getAttribute('data-bind')
    attrs = ko.utils.arrayPushAll([], node.attributes)
    binding = []
    attr_list = []
    event_list = []
    for attr in attrs when attr.specified and attr.name != 'data-bind' and attr.value.indexOf('{') != -1
      parts = []
      attr_value = ''
      class_applied = ''

      addText = (text) -> parts.push('"' + text.replace(/"/g, '\"') + '"') if text

      addExpr = (expression_text) ->
        if expression_text
          attr_value = expression_text
          if isObjectNotation(expression_text) or (braced = expression_text.indexOf('{') is 0)
            attr_value = '{' + expression_text + '}' unless braced
            parts.push(attr_value)
          else
            parts.push('ko.unwrap(' + expression_text + ')')

      parseInterpolationMarkup attr.value, addText, addExpr
      if parts.length > 1
        if attr.name is 'class'
          for p in parts
            if p.indexOf('{') is 0 or p.indexOf('ko.unwrap') is 0 then attr_value = p
            else class_applied += p.replace(/"/g, '').trim() + ' '
          node.setAttribute('class', class_applied.trim())
        else
          attr_value = '""+' + parts.join('+')
      if attr_value
        if attr.name in ['class', 'value', 'checked', 'ref'] or (attr.name.indexOf('on') is 0 and not node.lookupProp?(attr.name))
          switch attr.name
            when 'class'
              binding.push("css: #{attr_value}")
            when 'value', 'checked', 'ref'
              binding.push("#{attr.name}: #{attr_value}")
            else
              event_list.push("#{attr.name[2..]}: #{attr_value}")
        else
          attr_name = node.lookupProp?(attr.name) or attr.name
          attr_list.push("#{attr_name}: #{attr_value}")
        node.removeAttribute attr.name unless class_applied.length

    if attr_list.length
      binding_name = if !!Registry[Utils.toComponentName(node?.tagName)] then 'prop' else 'attr'
      binding.push(binding_name + ': {' + attr_list.join(', ') + '}')
    if event_list.length
      binding.push("event: {#{event_list.join(', ')}}")
    return unless binding.length
    if !data_bind_attribute
      data_bind_attribute = binding.join(', ')
    else
      data_bind_attribute += ', ' + binding.join(', ')
    node.setAttribute 'data-bind', data_bind_attribute

  if node.nodeType == 3 and node.nodeValue and node.nodeValue.indexOf('{') != -1 and (node.parentNode or {}).nodeName != 'TEXTAREA'
    nodes = []
    addTextNode = (text) -> nodes.push(document.createTextNode(text)) if text

    wrapExpr = (expressionText) ->
      if expressionText
        nodes.push.apply(nodes, wrapExpression(expressionText, node))

    parseInterpolationMarkup node.nodeValue, addTextNode, wrapExpr
    if nodes.length
      if node.parentNode
        i = 0
        n = nodes.length
        parent = node.parentNode
        while i < n
          parent.insertBefore nodes[i], node
          ++i
        parent.removeChild node
      return nodes