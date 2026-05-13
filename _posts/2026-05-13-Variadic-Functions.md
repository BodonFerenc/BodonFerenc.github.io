---
layout: post
title:  "Variadic functions in q"
date:   2026-05-13
tags: kdb q functions
toc: true
math: true
---

Variadic functions—those that accept a variable number of arguments—are among the most underutilized features in q. This is largely due to sparse documentation and a historical lack of idiomatic examples.

However, when paired with kdb+ 4.1 features like [type checking](https://code.kx.com/q/basics/pattern/#type-check) and [filter functions](https://code.kx.com/q/basics/pattern/#filter-function), variadic functions provide a robust, readable, and scalable approach to argument validation. This is particularly valuable when developing [kdb-x modules](https://code.kx.com/kdb-x/modules/module-index.html), where maintaining a clean and user-friendly API is paramount.

## The Variadic Pattern

in q, [enlist](https://code.kx.com/kdb-x/ref/enlist.html) is the only built-in function that natively accepts a variable number of arguments — and the only one that supports more than 8 parameters:

```q
q)enlist[1;2]
1 2
q)enlist[1;2;3;4;5;6;7;8;9;10]
1 2 3 4 5 6 7 8 9 10
```

To create custom variadic behavior, we leverage function composition. Composition — $f(g(x))$ — is expressed using the compose operator ([`'`](https://code.kx.com/kdb-x/ref/compose.html)). For example:

```q
q)f: {2*x}
q)g: {x+1}
q)'[f;g] 3  / 2*(3+1)
8
```

The composition must be wrapped in parentheses for the parser to handle assignment correctly:

```q
q)c: ('[f;g])
q)c 3
8
```

By using `enlist` as the second parameter in a composition, we create a function that captures all passed arguments into a single list before passing them to the primary logic:

```q
variadicFn: ('[{ ... }; enlist])
```

As a concrete example, Consider a function that calculates the future value of an investment:

$$\text{FutVal} = p \left(1 + \frac{r}{n}\right)^{n \times y}$$

In this model, the compounding frequency ($n$) typically defaults to 12 (monthly), but users may need to override it.

```q
futval: ('[{[params]
    (p; r; y): 3#params;
    n: $[3 = count params; 12; last params];

    p * (1 + r % n) xexp (n * y)
  };enlist])
```

The function can now be called with either three or four parameters:

```q
q)futval[100; 0.07; 30]         / Uses default n=12
811.6497
q)futval[100; 0.002; 30; 365]   / Overrides n=365
106.1836
```

## The Factory Pattern

To streamline development, we can define a factory function that wraps any lambda into an assignable variadic function:

```q
makeVariadic: ('[; enlist])
```

This abstracts the composition logic, making the intent clearer:

```q
futval: makeVariadic {[params]
    (p; r; y): 3#params;
    n: $[3 = count params; 12; last params];

    p * (1 + r % n) xexp (n * y)
  }
```

## Enhanced Type Checking

Leveraging the type-checking syntax introduced in kdb+ 4.1, we can enforce strict validation on both the number and types of parameters:

```q
futval: makeVariadic {[params]
    / Validate argument count
    if[not count[params] in 3 4;
        '"Function futval accepts 3 or 4 parameters, but received ", string count params];

    / Type checking via assignment
    (p:`j; r:`f; y:`j): 3#params;
    n: 12;
    if[4=count params;
        (n:`j): last params];       / type checking

    p * (1 + r % n) xexp (n * y)
  }
```

This triggers immediate, descriptive errors:

```q
q)futval[10]
'Function futval accepts 3 or 4 parameters, but received 1
  [0]  futval[10]
       ^

q)futval[100; 0.07; 30; 365.]    / passing a float instead of a long
'type
  [1]  /Users/kx/dev/variadic.q:7:
    if[4=count params;
        (n:`j): last params];
          ^
```

## Leveraging Filter Functions

Filter functions help validate function parameters in a consistent, reusable way. They allow us to normalize inputs and separate preprocessing logic from core implementation. As an example, consider a function `fn` that accepts a kdb+ database root directory.

```q
getFSym: {hsym $[10h~type x;`$;] x}

fn: {[db:getFSym] 0N!db;}
```

Internally, the function works with a file symbol, but callers are free to pass a string, symbol, or file symbol.

```q
q)fn "/tmp/kdbdb"
`:/tmp/kdbdb
q)fn `:/tmp/kdbdb
`:/tmp/kdbdb
```

Filter functions can also be applied within the function body. In our future value example, the optional parameter must be a positive integer — accepting a short, int, or long.

```q
positiveNumber: {[name:`C; v]
    if[not 0<x; 'name, " must be a positive number"];
    if[not .Q.ty[x] in "HIJ"; 'name, " must be either a short, int or long"];
    x
 }

futval: makeVariadic {[params]
    if[not count[params] in 3 4;
        '"Function futval accepts 3 or 4 parameters, but received ", string count params];
    (p:`j; r:`f; y:`j): 3#params;
    n: 3;
    if[4=count params;
        (n:positiveNumber["fourth parameter"]): last params];

    p * (1 + r % n) xexp (n * y)
  }
```

Example usage:

```q
q)futval[100; 0.07; 30; -1]
'fourth parameter must be a positive number
  [2]  /Users/kx/dev/variadic.q:3: positiveInteger:{[name:`C; v]
    if[not 0<v; 'name, " must be a positive number"];
                ^
    if[not .Q.ty[v] in "HIJ"; 'name, " must be either a short, int or long"];
  [1]  /Users/kx/dev/variadic.q:14:
    if[4=count params;
        (n:positiveInteger["fourth parameter"]): last params];
```

## Scaling with Optional Parameters

For functions with extensive configuration options, passing a dictionary is the most scalable approach. This avoids "parameter bloat" and makes the API easier to maintain as it evolves. This approach scales naturally as the module evolves and new options are added. For example, `buildPersistedDB` from the [Datagen module](https://code.kx.com/kdb-x/modules/datagen/overview.html) has one mandatory parameter and eleven optional ones. The [dictionary literal syntax](https://code.kx.com/kdb-x/how_to/basics/data_structures/dictionaries.html#dictionary-literal-syntax) introduced in kdb+ version 4.1 comes in handy. Let us see a complex example of a "production" code:

```q
DEFAULTS: ([
  tradesPerDay: 1000;   / nr of trades per day
  exchopen: 09:30;      / exchange open time
  exchclose: 16:00;     / exchange close time
  quotesPerTrade: 10;   / number of quotes per trade
  nbboPerTrade: 3       / nr of nbbo per trade
  tbls: `trade`quote`nbbo`daily;    / tables to generate
  mastertype: `flat;    / type of the master table (flat or splayed)
  holidays: ("01.01"; "01.19"; "02.16"; "05.25"; "06.19"; "07.03"; "09.07"; "10.12"; "11.11"; "11.26"; "12.25");
  segmentNr: 0;         / nr of segments
  segmentPattern: "/tmp/mnt/ssd{}/testdata";    / segment pattern
  linked: 0b])          / 1b to generate linked columns
```

A dedicated helper function to process optional parameters — or the full parameter list — keeps the main function clean and focused.

```q
processOptParam:{[allowedKeys; optparam]
  if[not 99h = type optparam;
    '"A numeric or a dictionary is expected as optional parameter"];

  unknownParams: (key optparam) except allowedKeys;
  if[count unknownParams; '"Unknown parameter(s): ", "," sv string unknownParams];

  if[`tbls in key optparam;
    optparam: (`tbls _ optparam), ([tbls: $[count optparam `tbls; (), optparam `tbls; `$()]]); / a  symbol or a general empty list are also accepted
    unknownTbls: optparam[`tbls] except `trade`quote`nbbo`daily;
    if[count unknownTbls; '"Unknown table(s) in tbls parameter: ", "," sv string unknownTbls]];

  if[`mastertype in key optparam;
    if[not p[`mastertype] in `flat`splayed;
      '"Invalid mastertype parameter, expected `flat or `splayed"]];

  optparam
  }
```

The main function

```q
buildPersistedDB: ('[{[params]
  if[2<count params; '"Too many parameters passed to buildPersistedDB"];
  if[(::) ~ first params;
    '"Destination directory must be provided as first parameter to buildPersistedDB"];
  (dst: getFSym): first params;
  p: DEFAULTS;
  if[1 < count params;
    p,: processOptParam[key p; last params]];
  ...
  };enlist])
```

## Summary

By combining variadic compositions, 4.1 type checking, and filter functions, you can build q APIs that are both flexible and "fail-fast." Separating parameter validation from the core implementation results in code that is easier to test, document, and extend.