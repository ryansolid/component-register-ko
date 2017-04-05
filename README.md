Introduction
============

Component Register KO is a Knockout specific implementation of Component Register. It also includes custom bindings, extensions, and preprocessor to modernize the use of Knockout. Think of this as an example of how you could write a micro framework based on the Component Register library. Note this makes no use of Knockouts Components.  Those bindings and approach to custom elments are mired in Knockout's binding language and are based on passing observables through. This approach only internally uses Knockout and can be mixed and matched with any other library/framework without writing any Knockout in its consumption including when passing children elements into the components (when used with the shadow dom).

Some key extras:
* React-like syntax from the preprocessor (for text and attribute bindings)
* '$' data-bind shorthand for templates
* Reference cleanup functionality
* Observable mapping observable fn
* Explicit computed sync mechanism
* 'use' binding for creating binding context (essentially 'with' binding without forced redraw)
* 'ref' binding to extract HTML element (to avoid necessity of custom bindings or spaghetti selectors)

TODO: Write documentation

TODO: Write tests
