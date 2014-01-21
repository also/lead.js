# lead.js

[![Build Status](https://travis-ci.org/also/lead.js.png?branch=master)](https://travis-ci.org/also/lead.js)

lead.js is a CoffeeScript console for exploring data, inspired by tools like [Mathematica](http://www.wolfram.com/mathematica/) and [The IPython Notebook](http://ipython.org/notebook.html). Its focus is on graphing time-series data from systems like [Graphite](http://graphite.readthedocs.org/en/latest/overview.html) and [OpenTSDB](http://opentsdb.net/).

## Features

 * **Graphite target DSL**: write Graphite queries with ease.
 * **GitHub integration**: save and load files directly from Gists or repositories.
 * **Autocompletion**: lead.js suggests commands or Graphite target functions.
 * **Extensible**: integrate your own functions and data sources.

## Missing Features

 * Useful documentation for most built-in functions.
 * An actual REPL. Each cell runs in its own scope. (https://github.com/also/lead.js/issues/9).

## Documentation

[Installation](docs/installation.md)

[Quick Start](docs/quickstart.md)

[Graphing](docs/graphing.md)

[OpenTSDB](docs/opentsdb.md)

[Graphite DSL function list](http://lead.github.io/?ZG9jcw%3D%3D)

[lead.js built-in functions](http://lead.github.io/?aGVscA%3D%3D)

## License

lead.js is released under the [MIT License](http://opensource.org/licenses/MIT).
