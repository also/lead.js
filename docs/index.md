# Notebooks

A *notebook* is a collection of input and output cells.

## Contexts

Each input cell defines a *program* that runs in a *context*. The context provides the program with an output cell it can manipulate.

### Scripting Functions

A *scripting function* is a function that is has access to the current context. It will be called with the context as the first argument.

### Scripting Commands

A *scripting command* is a scripting function that will be invoked if it is the return value of the script. So,

```coffeescript
help
```

is the same as

```coffeescript
help()
```

### Scripting Vars

A *scripting var* is simply a variable that is made available in the scripting scope.

## Modules

A lead.js module provides a set of functionality. It is implemented as a CommonJS style module, and uses the `modules` module to set expose its features.

The `modules` module provides helpers to define commands, functions, and to access settings.

```coffeescript
{fn, cmd, context_fn, settings} = modules.create 'github'
settings.set 'default', 'github.com'
```

The `settings` object returned by `modules.create` will use the `github` prefix for all its settings.

### Extension Points

A module can provide functionality through an *extension point*. An extension point is an attribute of the module that will be used by other modules. A context will look at all loaded modules and collect the attributes.

Notable extension points include
 * `scriptingExports`
