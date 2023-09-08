---
layout: post
title:  "Productivity Tip No. 2: qcon"
date:   2023-09-08
category: "kdb+ productivity tips"
tags: kdb
toc: false
---
There are several IDEs available for kdb+, including the soon-to-be-released Visual Studio KX plugin, KX [Developer](https://code.kx.com/developer)/[Analyst](https://code.kx.com/analyst/), [Studio for kdb+](https://github.com/CharlesSkelton/studio), etc. Often, you find yourself working in a terminal and would simply like to execute some function on a remote kdb+ process. Typically, you start a kdb+ process, create a connection handler (`h`) and send the command synchronously.

If you send the command as a string then escaping quotation marks is inconvenient. On the other hand, if you send your expression as a list (function name and parameters), you might be annoyed by the extra punctuations (e.g. backtick for the function, parentheses). A simple

```q
f 43
```

becomes

```q
h "f 43"
```

or

```q
h (`f; 43)
```

The command line tool [qcon](https://github.com/KxSystems/kdb/tree/master/l64) comes to rescue. If you type

```bash
$ qcon remotehost:5050
remotehost:5050>
```

it connects to the remote kdb+ process and provides you a prompt. Commands that you enter there are executed on the remote server. Quite convenient, isn't it?

`qcon` is available for all operating system for which kdb+ binary is built. On Linux, it is recommended to use [rlwrap](https://github.com/hanslub42/rlwrap) with `qcon` to enable arrow keys and navigation in the command history.

Interestingly, `qcon` triggers callback [.z.pq](https://code.kx.com/q/ref/dotz/#zpq-qcon) as opposed to [.z.pg](https://code.kx.com/q/ref/dotz/#zpg-get) on the remote server. Be aware of this when you implement security checks.

`qcon` hangs till the results are returned. [Geo's con](https://github.com/geocar/con) command is asynchronous, allowing you to start typing your next lengthy command immediately without waiting for the results of the previous commands.

kdb+ developers often find it frustrating that the q console lacks support for multi-line commands. Overwriting a multi-line function is a typical practice during development or root cause investigation.
Another exciting `qcon` replica is [qcon2.sh](https://github.com/patmok/qcon2), which supports sending multi-line commands. You need to type `p)` (that has nothing to do with the [ANSI SQL kdb+](https://code.kx.com/insights/1.7/core/sql.html) interface) and can past a multi-line command.