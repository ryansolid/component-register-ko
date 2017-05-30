ko = require 'knockout'
{Utils} = require 'component-register'

###
# Patch ko to consider nodes connected to shadowRoots are still connected to document
###
orig_attached = ko.utils.domNodeIsAttachedToDocument
ko.utils.domNodeIsAttachedToDocument = (node) ->
  return true if node.isConnected or orig_attached.call(@, node)
  return false unless Utils.useShadowDOM
  null while (node = node.parentNode or node.host) and node isnt document.documentElement
  node is document.documentElement

require './release'
require './project'