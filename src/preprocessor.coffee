import { parse, stringify } from 'html-parse-string'

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

wrapExpression = (expressionText) ->
  result = []
  result.push {type: 'comment', content: 'ko text: ' + trim(expressionText)}
  result.push {type: 'comment', content: '/ko'}
  result

transformList = (nodes) ->
  for node in nodes[..]
    switch node.type
      when 'tag'
        continue if node.name is 'style'
        dataBindAttribute = node.attrs['data-bind']
        binding = []
        attrList = []
        eventList = []
        for attr, value of node.attrs when attr isnt 'data-bind'
          attrValue = ''
          classApplied = ''
          if value.indexOf('{') isnt -1
            parts = []
            addText = (text) -> parts.push("'" + text.replace(/"/g, '\"') + "'") if text

            addExpr = (expressionText) ->
              if expressionText
                attrValue = expressionText
                if OBJECT_NOTATION.test(expressionText) or (braced = expressionText.indexOf('{') is 0)
                  attrValue = '{' + expressionText + '}' unless braced
                  parts.push(attrValue)
                else
                  parts.push('ko.unwrap(' + expressionText + ')')

            parseInterpolationMarkup value, addText, addExpr
            if parts.length > 1
              if attr is 'class'
                for p in parts
                  if p.indexOf('{') is 0 or p.indexOf('ko.unwrap') is 0 then attrValue = p
                  else classApplied += p.replace(/'/g, '').trim() + ' '
                node.attrs['class'] = classApplied.trim()
              else attrValue = "''+" + parts.join('+')
          else if attr.indexOf('$') is 0
            attrValue = "'#{value}'"

          if attrValue
            switch
              when attr.indexOf('on') is 0
                eventList.push("#{attr[2..]}: #{attrValue}")
              when attr.indexOf('$') is 0
                binding.push("#{attr[1..]}: #{attrValue}")
              when attr is 'class'
                binding.push("css: #{attrValue}")
              when attr is 'style'
                binding.push("csstext: #{attrValue}")
              else
                attrList.push("'#{attr}': #{attrValue}")
            delete node.attrs[attr] unless classApplied.length

        if attrList.length
          binding.push("prop: {#{attrList.join(', ')}}")
        if eventList.length
          binding.push("event: {#{eventList.join(', ')}}")
        if binding.length
          if !dataBindAttribute
            dataBindAttribute = binding.join(', ')
          else
            dataBindAttribute += ', ' + binding.join(', ')
          node.attrs['data-bind'] = dataBindAttribute
        transformList(node.children) if node.children?.length and not (node.name in ['textarea'])
      when 'text'
        continue if node.content.indexOf('{') is -1
        parsedNodes = []
        addTextNode = (text) -> parsedNodes.push({type: 'text', content: text}) if text
        wrapExpr = (expressionText) ->
          if expressionText
            parsedNodes.push.apply(parsedNodes, wrapExpression(expressionText))

        parseInterpolationMarkup node.content, addTextNode, wrapExpr
        if parsedNodes.length
          index = nodes.indexOf(node)
          nodes.splice.apply(nodes, [index, 1].concat(parsedNodes))
  return

export default (text) ->
  parsed = parse(text)
  if text and not parsed.length
    parsed.push({type: 'text', content: text})
  transformList(parsed)
  stringify(parsed)