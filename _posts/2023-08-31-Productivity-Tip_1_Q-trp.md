---
layout: post
title:  "Productivity tip Nr. 1: call stack for remote function calls"
date:   2023-08-31
category: kdb+ productivity tips
tags: kdb
toc: false
---
Fiona is a developer with limited kdb+ experience, often finds herself facing a challenge. She needs to execute a function (stored procedure) on the remote kdb+ server maintained by her IT people. Armed with VS Code's kdb+ plugin (or other tools like KX Developer or kdb+ Studio) she successfully connects to the kdb+ server and inputs the function name, sets the parameters, and hits the run command. However, instead of the expected outcome, she's greeted by a puzzling `'type` error. Just a `'type` error, nothing else. Fiona, like many kdb+ users, grapples with debugging and spends significant time tinkering with parameter values until success.

Fiona's colleague, Laszlo, also encountered a similar roadblock, though his journey to a solution was longer. Although the parameter types seemed correct — some inputs yielded results while others triggered `'type` errors. He discovered that the function mishandled empty internal results. For Laszlo, remote debugging became an arduous task.

Debugging is straightforward when you're running the kdb+ process locally. You're privy to error locations, variable observations, call stack printing, and the freedom to traverse the stack levels.

```q
q)double: {2*x}
q)add:{x + double y}
q)add[3; `foo]
'type
  [2]  double:{2*x}
                ^
q))x
`foo
q)).Q.bt[]
>>[2]  double:{2*x}
                ^
  [1]  add:{x + double y}
                ^
  [0]  add[3; `foo]
q))`     / move up in the stack
  [1]  add:{x + double y}
                ^
q))x
3
```

However, when dealing with a remote kdb+ process, you're met with a stark `'type` error devoid of any contextual information regarding its origin. Assuming the connection handler is referenced as `h`, and the server holds the definitions of functions `double` and `add`, the following occurs:

```q
q)h "add[3; `foo]"
'type
  [0]  h "add[3; `foo]"
```

Here's where the extended trap function [.Q.trp](https://code.kx.com/q/ref/dotq/#trp-extend-trap)  together with [.Q.sbt](https://code.kx.com/q/ref/dotq/#sbt-string-backtrace) come to the rescue. You can execute your function in a protected mode and you can capture the call stack in case of errors:

```q
q)1 h ({.Q.trp[value; x; {.Q.sbt y}]}; "add[3; `foo]")
  [4]  double:{2*x}
                ^
  [3]  add:{x + double y}
                ^
  [2]  add[3; `foo]
       ^
  [1]  (.Q.trp)

  [0]  {.Q.trp[value;x;{.Q.sbt y}]}
        ^
1
```

In scenarios where the `value` function is restricted on the server due to security concerns, you can devise a [projection](https://code.kx.com/q/basics/application/#projection) to obtain a monadic function:

```q
q)1 h ({.Q.trp[add[3]; x; {.Q.sbt y}]}; `foo)
```

Bonus tip: Keep an eye out for an upcoming kdb+ release that enhances error handling. Refer to [Pierre's demo](https://kx.com/videos/kx-con-23-kx-core-developments/) at KX Con 2023 for more insights.


