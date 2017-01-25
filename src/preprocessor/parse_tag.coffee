###
# Based on package html-parse-stringify2
###
attrRE = /([\w-]+)|(['"])(.*?)\2/g
lookup =
  area: true, base: true
  br: true, col: true
  embed: true, hr: true
  img: true, input: true
  keygen: true, link: true
  menuitem: true, meta: true
  param: true, source: true
  track: true, wbr: true

module.exports = (tag) ->
  i = 0
  key = undefined
  res = {type: 'tag', name: '', voidElement: false, attrs: {}, children: []}
  tag.replace attrRE, (match) ->
    if i % 2
      key = match
    else
      if i == 0
        if lookup[match] or tag.charAt(tag.length - 2) == '/'
          res.voidElement = true
        res.name = match
      else
        res.attrs[key] = match.replace(/^['"]|['"]$/g, '')
    i++
    return
  res