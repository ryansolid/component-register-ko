Introduction
============

Component Register KO is a Knockout specific implementation of Component Register. It also includes custom bindings, extensions, and preprocessor to reflect my current conventions on how to structure KO components. This is just my current opinion of how this work. Think of this more of an example of how you could write a micro framework based on the Component Register library. Note this makes no use of Knockouts Components.  Those bindings and approach to custom elments is mired in Knockout's binding language and are based on passing observables through. This approach only internally uses Knockout and can be mixed and matched with any other library/framework without writing any Knockout in its consumption including when passing children elements into the components.

Some key extras:
* React like syntax from the preprocessor (for non control flow bindings).
* Update attr binding to default to JSON.stringify javascript objects
* Reference cleanup functionality
* Explicit computed sync mechanism
* Inject binding as alternative to named slots to inject templates
* Wrap binding to map models to binding context

TODO: Write documentation
TODO: Write tests
