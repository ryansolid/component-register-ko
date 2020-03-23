import ko from 'knockout'

###
# Patch ko to consider nodes connected to shadowRoots are still connected to document
###
origAttached = ko.utils.domNodeIsAttachedToDocument
ko.utils.domNodeIsAttachedToDocument = (node) ->
  return true if node.isConnected or origAttached.call(@, node)
  null while (node = node.parentNode or node.host) and node isnt document.documentElement
  node is document.documentElement

import './release'
import './reactive'