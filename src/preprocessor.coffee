parse = require 'component-register/lib/html/parse'
stringify = require 'component-register/lib/html/stringify'

###
# Based on knockout.punches and altered to handle prop binding
# Uses string parsing instead of knockout runtime preprocessor
# Currently supports attr, prop, and text bindings using { } syntax.
# value, css(as class), event(as on*), checked, and ref bindings are also pushed to attributes
###
OBJECT_NOTATION = /^[^{(}(?]+:.+/

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
  return '' unless string
  string.trim()

wrapExpression = (expression_text) ->
  result = []
  result.push {type: 'comment', content: 'ko text: ' + trim(expression_text)}
  result.push {type: 'comment', content: '/ko'}
  result

transformList = (nodes) ->
  for node in nodes[..]
    switch node.type
      when 'tag'
        data_bind_attribute = node.attrs['data-bind']
        binding = []
        attr_list = []
        event_list = []
        for attr, value of node.attrs when attr isnt 'data-bind' and value.indexOf('{') isnt -1
          parts = []
          attr_value = ''
          class_applied = ''

          addText = (text) -> parts.push("'" + text.replace(/"/g, '\"') + "'") if text

          addExpr = (expression_text) ->
            if expression_text
              attr_value = expression_text
              if OBJECT_NOTATION.test(expression_text) or (braced = expression_text.indexOf('{') is 0)
                attr_value = '{' + expression_text + '}' unless braced
                parts.push(attr_value)
              else
                parts.push('ko.unwrap(' + expression_text + ')')

          parseInterpolationMarkup value, addText, addExpr
          if parts.length > 1
            if attr is 'class'
              for p in parts
                if p.indexOf('{') is 0 or p.indexOf('ko.unwrap') is 0 then attr_value = p
                else class_applied += p.replace(/'/g, '').trim() + ' '
              node.attrs['class'] = class_applied.trim()
            else attr_value = "''+" + parts.join('+')
          if attr_value
            if attr in ['class', 'value', 'checked', 'ref'] or attr.indexOf('on') is 0
              switch attr
                when 'class'
                  binding.push("css: #{attr_value}")
                when 'value', 'checked', 'ref'
                  binding.push("#{attr}: #{attr_value}")
                else
                  event_list.push("#{attr[2..]}: #{attr_value}")
            else
              attr_list.push("'#{attr}': #{attr_value}")
            delete node.attrs[attr] unless class_applied.length

        if attr_list.length
          binding.push('prop: {' + attr_list.join(', ') + '}')
        if event_list.length
          binding.push("event: {#{event_list.join(', ')}}")
        if binding.length
          if !data_bind_attribute
            data_bind_attribute = binding.join(', ')
          else
            data_bind_attribute += ', ' + binding.join(', ')
          node.attrs['data-bind'] = data_bind_attribute
        transformList(node.children) if node.children?.length and not (node.name in ['textarea'])
      when 'text'
        continue if node.content.indexOf('{') is -1
        parsed_nodes = []
        addTextNode = (text) -> parsed_nodes.push({type: 'text', content: text}) if text
        wrapExpr = (expression_text) ->
          if expression_text
            parsed_nodes.push.apply(parsed_nodes, wrapExpression(expression_text))

        parseInterpolationMarkup node.content, addTextNode, wrapExpr
        if parsed_nodes.length
          index = nodes.indexOf(node)
          nodes.splice.apply(nodes, [index, 1].concat(parsed_nodes))
  return

module.exports = (text) ->
  parsed = parse(text)
  if text and not parsed.length
    parsed.push({type: 'text', content: text})
  transformList(parsed)
  stringify(parsed)