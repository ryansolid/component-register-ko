var Registry, Utils, ko, parseInterpolationMarkup, ref, trim, wrapExpression;

ko = require('knockout');

ref = require('component-register'), Registry = ref.Registry, Utils = ref.Utils;


/* Based on knockout.punches and altered to handle prop binding and not generic bindings
 * Currently supports attr, prop, and text bindings using { } syntax.
 * value, css(as class), event(as on*), checked bindings are also pushed to attributes
 */

parseInterpolationMarkup = function(textToParse, outerTextCallback, expressionCallback) {
  var innerParse, outerMatch;
  outerMatch = textToParse.match(/^([\s\S]*?)\{([\s\S]*)}([\s\S]*)$/);
  innerParse = function(text) {
    var innerMatch;
    innerMatch = text.match(/^([\s\S]*)}([\s\S]*?)\{([\s\S]*)$/);
    if (innerMatch) {
      innerParse(innerMatch[1]);
      outerTextCallback(innerMatch[2]);
      return expressionCallback(innerMatch[3]);
    } else {
      return expressionCallback(text);
    }
  };
  if (outerMatch) {
    outerTextCallback(outerMatch[1]);
    innerParse(outerMatch[2]);
    return outerTextCallback(outerMatch[3]);
  }
};

trim = function(string) {
  if (string === null) {
    return '';
  } else if (string.trim) {
    return string.trim();
  } else {
    return string.toString().replace(/^[\s\xa0]+|[\s\xa0]+$/g, '');
  }
};

wrapExpression = function(expressionText, node) {
  var ownerDocument, result;
  ownerDocument = node ? node.ownerDocument : document;
  result = [];
  result.push(ownerDocument.createComment('ko ' + 'text:' + trim(expressionText)));
  result.push(ownerDocument.createComment('/ko'));
  return result;
};

ko.bindingProvider.instance.preprocessNode = function(node) {
  var addExpr, addText, addTextNode, attr, attr_list, attr_name, attr_value, attrs, binding, binding_name, data_bind_attribute, event_list, i, j, len, n, nodes, parent, parts, ref1, wrapExpr;
  if (node.nodeType === 1 && node.attributes.length) {
    data_bind_attribute = node.getAttribute('data-bind');
    attrs = ko.utils.arrayPushAll([], node.attributes);
    binding = [];
    attr_list = [];
    event_list = [];
    for (j = 0, len = attrs.length; j < len; j++) {
      attr = attrs[j];
      if (!(attr.specified && attr.name !== 'data-bind' && attr.value.indexOf('{') !== -1)) {
        continue;
      }
      parts = [];
      attr_value = '';
      addText = function(text) {
        if (text) {
          return parts.push('"' + text.replace(/"/g, '\"') + '"');
        }
      };
      addExpr = function(expression_text) {
        if (expression_text) {
          attr_value = expression_text;
          return parts.push('ko.unwrap(' + expression_text + ')');
        }
      };
      parseInterpolationMarkup(attr.value, addText, addExpr);
      if (parts.length > 1) {
        attr_value = '""+' + parts.join('+');
      }
      if (attr_value) {
        if (((ref1 = attr.name) === 'class' || ref1 === 'value' || ref1 === 'checked') || (attr.name.indexOf('on') === 0 && !(typeof node.lookupProp === "function" ? node.lookupProp(attr.name) : void 0))) {
          switch (attr.name) {
            case 'class':
              binding.push("css: " + attr_value);
              break;
            case 'value':
            case 'checked':
              binding.push(attr.name + ": " + attr_value);
              break;
            default:
              event_list.push(attr.name.slice(2) + ": " + attr_value);
          }
        } else {
          attr_name = (typeof node.lookupProp === "function" ? node.lookupProp(attr.name) : void 0) || attr.name;
          attr_list.push(attr_name + ": " + attr_value);
        }
        node.removeAttribute(attr.name);
      }
    }
    if (attr_list.length) {
      binding_name = !!Registry[Utils.toComponentName(node != null ? node.tagName : void 0)] ? 'prop' : 'attr';
      binding.push(binding_name + ': {' + attr_list.join(', ') + '}');
    }
    if (event_list.length) {
      binding.push("event: {" + (event_list.join(', ')) + "}");
    }
    if (!binding.length) {
      return;
    }
    if (!data_bind_attribute) {
      data_bind_attribute = binding.join(', ');
    } else {
      data_bind_attribute += ', ' + binding.join(', ');
    }
    node.setAttribute('data-bind', data_bind_attribute);
  }
  if (node.nodeType === 3 && node.nodeValue && node.nodeValue.indexOf('{') !== -1 && (node.parentNode || {}).nodeName !== 'TEXTAREA') {
    nodes = [];
    addTextNode = function(text) {
      if (text) {
        return nodes.push(document.createTextNode(text));
      }
    };
    wrapExpr = function(expressionText) {
      if (expressionText) {
        return nodes.push.apply(nodes, wrapExpression(expressionText, node));
      }
    };
    parseInterpolationMarkup(node.nodeValue, addTextNode, wrapExpr);
    if (nodes.length) {
      if (node.parentNode) {
        i = 0;
        n = nodes.length;
        parent = node.parentNode;
        while (i < n) {
          parent.insertBefore(nodes[i], node);
          ++i;
        }
        parent.removeChild(node);
      }
      return nodes;
    }
  }
};
