---
layout: post
title:  "Variadic functions in q"
date:   2026-05-13
tags: kdb q functions
toc: true
---

# Background

Variadic functions in q are one of the most underutilized features of the language, due largely to sparse documentation and a lack of compelling examples.

Variadic functions accept a variable number of arguments. Used alongside kdb+ 4.1 features such as [type checking](https://code.kx.com/q/basics/pattern/#type-check) and [filter functions](https://code.kx.com/q/basics/pattern/#filter-function), they provide a robust, readable, and scalable approach to argument validation. This is especially valuable when building [kdb-x modules](https://code.kx.com/kdb-x/modules/module-index.html), where a clear and user-friendly API is essential.

## Variadic functions

`enlist` is the only built-in q function that accepts a variable number of arguments — and the only one that supports more than 8 parameters:

```q
q)enlist[1;2]
1 2
q)enlist[1;2;3;4;5;6;7;8;9;10]
1 2 3 4 5 6 7 8 9 10
```

Function composition — `f(g(x))` — can be expressed in q using the compose operator [`'`](https://code.kx.com/kdb-x/ref/compose.html), for example:

```q
q)f: {2*x}
q)g: {x+1}
q)'[f;g] 3  / 2*(x+1) = 2*4
8
```

The composition must be wrapped in parentheses for the parser to handle assignment correctly:

```q
q)c: ('[f;g])
q)c 3
8
```

Having `enlist` as the second parameter creates a variadic function that accepts a list as a single parameter:

```q
variadicFn: ('[{ ... }; enlist])
```

As a concrete example, consider a function that computes the future value

$$\text{FutVal} = p \left(1 + \frac{r}{n}\right)^{n \times y}$$

of an investment. The compounding frequency (how often interest is applied - parameter `n`) defaults to 12, but callers may override it when needed.

```q
futval: ('[{[params]
    (p; r; y): 3#params;
    n: $[3 = count params; 12; last params];

    p * (1 + r % n) xexp (n * y)
  };enlist])
```

We can call the function with 3 or 4 parameters:

```q
q)futval[100; 0.07; 30]         / using default compounding frequency, 12
811.6497
q)futval[100; 0.002; 30; 365]   / overriding compounding frequency with 365
106.1836
```

## Factory

Let us create a factory function that wraps a lambda into an assignable variadic function:

```q
makeVariadic: : ('[; enlist])
```

This factory function simplifies the code:

```q
futval: makeVariadic {[params]
    (p; r; y): 3#params;
    n: $[3 = count params; 12; last params];

    p * (1 + r % n) xexp (n * y)
  }
```

## Type checking

We can strengthen parameter handling by validating:

- the number of parameters
- the types of parameters

```q
futval: makeVariadic {[params]
    if[not count[params] in 3 4;    / parameter count checking
        '"Function futval accepts 3 or 4 parameters, but received ", string count params];
    (p:`j; r:`f; y:`j): 3#params;   / type checking
    n: 12;
    if[4=count params;
        (n:`j): last params];       / type checking

    p * (1 + r % n) xexp (n * y)
  }
```

We can verify these checks by passing invalid arguments:

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

## Filter functions

Filter functions help validate function parameters in a consistent, reusable way. The function body can then assume valid input, and preprocessing logic is cleanly separated from the core implementation. As an example, consider a function `fn` that accepts a kdb+ database root directory.

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

## Optional parameters

When a function has multiple optional parameters, it is recommended to pass them as a dictionary. This approach scales naturally as the module evolves and new options are added. For example, `buildPersistedDB` from the [Datagen module](https://code.kx.com/kdb-x/modules/datagen/overview.html) has one mandatory parameter and eleven optional ones. The [dictionary literal syntax](https://code.kx.com/kdb-x/how_to/basics/data_structures/dictionaries.html#dictionary-literal-syntax) introduced in kdb+ version 4.1 comes in handy. Let us see a complex example of a "production" code:

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

Combining variadic functions, type checking, and filter functions — with parameter handling separated from core logic — produces clean, robust, and easy-to-use q functions.
