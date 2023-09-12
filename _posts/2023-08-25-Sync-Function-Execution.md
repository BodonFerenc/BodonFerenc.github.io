---
layout: post
title:  "Achieving Simultaneous Execution of a Function Across Multiple kdb+ Processes"
date:   2023-08-25
category: kdb+ tutorial
tags: kdb
toc: true
---

Implementing concurrent execution of a function across several kdb+ processes simultaneously is an interesting topic worth investigating. While this requirement might not be a common use case, it becomes essential in scenarios such as evaluating storage performance scaling under simultaneous disk read operations within a storage performance tool - see [nano storage performance tool](https://github.com/KxSystems/nano) that triggered this small research.

The orchestration of this function execution is controlled by a central kdb+ process acting as a controller. The controller facilitates communication with worker processes responsible for executing the function. I considered two methods, namely [qIPC](https://code.kx.com/q/basics/ipc/) (q Inter-Process Communication) and file operations to transmit execution messages from the controller to worker processes.

The worker processes are configured to listen on distinct addresses, such as `host1:port1`, `host2:port2`, and `host3:port3`. The goal is to execute a function, denoted as `f`, across these worker processes. Notably, function `f` does not require any parameters. The list of worker addresses is defined as `A`:

```q
addr: ("host1:port1"; "host2:port2"; "host3:port3")
A: hsym `$addr
H: hopen each A
```

Synchronization solutions encompass multiple options, including TCP/Unix Domain Socket messages, file-based mechanisms, and CPU counters. Let's explore these approaches in detail.

## peach-based solutions
One technique to achieve parallel execution is by leveraging the parallel each ([peach](https://code.kx.com/q/ref/each/)) construct.

### sync message

Sending synchronous messages within `peach` threads is a risky proposition due to potential message interleaving, as specified in the [KX documentation](https://code.kx.com/q/basics/peach/#sockets-and-handles).

> A handle must not be used concurrently between threads as there is no locking around a socket descriptor, and the bytes being read/written from/to the socket will be garbage (due to message interleaving) and most likely result in a crash.

If we start the controller with an equivalent number of secondary threads as worker processes then each handler can have its own thread.

```q
@[; (`f; ::)] peach H //Pass list of existing (H)andles
```

Thus method is denoted by `peach sync` in the Results section.

This approach is no longer supported in later kdb+ versions including kdb+ cloud edition (aka. [KX Insights Core](https://code.kx.com/insights/1.6/insights/)). See kdb+ 4.1 release notes

```
2021.03.30
NUC
using handles within peach is temporarily not supported, to be reviewed in the near future e.g.
 q)H:hopen each 4#4000;{x""}peach H
 3 4 5 6i
one-shot ipc requests can be used within peach instead.
```

### one-shot request (`peach one-shot`)
In cases where the controller cannot be started with a sufficient number of threads, [one-shot requests](https://code.kx.com/q/basics/ipc/#sync-request-get) can be employed. This technique involves opening a connection, sending a synchronous message, and then closing the connection instantly. Unlike the previous approach, this method is safe to use within `peach`:

```q
@[; (`f; ::)] peach A //Pass list of (A)ddresses
```

The controller kdb+ process must be started with a positive integer [-s](https://code.kx.com/q/basics/cmdline/#-s-secondary-threads) command line parameter.

This approach introduces the overhead of establishing and closing connections for each task, impacting overall efficiency.

### peach handlers (`peach handles`)

peach handlers are open connection handlers to remote kdb+ processes that kdb+ sends the function to execute during a `peach` statement. kdb+ assigns the tasks sequentially to the list of remote handles as defined in [.z.pd](https://code.kx.com/q/ref/dotz/#zpd-peach-handles) via a synchronous message call. If the length of the input list equals the number of remote processes then kdb+ guarantees that each kdb+ process gets one request.

```q
.z.pd: `u#H
f peach til count H
```

The controller kdb+ process must be started with a negative integer `-s` command line parameter.

Function `f` and all its dependencies need to be defined in the controller and in the workers. You can load the definition from files or transfer it via qipc. This constraint causes some inconvenience and has some maintenance costs.

## each-based solution

We can iterate over the list of hosts or connection handlers by iterator `each`. `each` starts the tasks sequentially which means it waits till the previous task is finished. We need to make sure that starting the task, i.e. sending the start signal does not block the sender. We can achieve this by sending [asynchronous messages](https://code.kx.com/q/basics/ipc/#async-message-set).

We implemented four async approaches:
   * `each async`: vanilla solution, i.e. sending a message via `neg h`.
   * `each async flush`: The primary purpose of async messages is to avoid the sender being blocked and it does not guarantee that message is sent immediately. Actual sending is up to the operating system. This adds variance to the arrival times of the messages. We can reduce sending latency by [flushing the outgoing queue](https://code.kx.com/q/basics/ipc/#async-message-set) (`neg[h][]`).
   * `async broadcast flush`: We send the same message to all workers. We can save serializing the same message by using an [asynchronous broadcast](https://code.kx.com/q/basics/internal/#-25x-async-broadcast) (`-25!`). The benefit of async broadcast is more obvious with large messages so we don't expect significant improvement in our case.
   * `each async time`: Our original goal is not to reduce the latency of sending but to start the function at the same time. We can achieve this by a timer in the worker and using async messages only to trigger the timer. kdb+'s timer solution is millisecond-based. If the workers are idle between task executions then we can fully spin the CPU and just increase a counter till the target time is reached (`a:0; while[.z.p<target;a+:1]`)

Another tool of parallel execution is [deferred responses](https://code.kx.com/q/kb/deferred-response/) which are generally used in implementations of kdb+ gateways. Deferred responses are used with synchronous messages to suspend the execution of the actual request to give CPU to other requests. Deferred responses do not help in our case because it frees up the workers as opposed to the controller, which remains blocked.

## file-watching based solution (`async InotifyWait`)

An alternative synchronization method involves file monitoring. Processes can execute the function upon detecting specific file operations. If the worker processes are spread across different servers then you need a shared file system that supports monitoring.

Linux's [inotify](https://man7.org/linux/man-pages/man7/inotify.7.html) function (available in the package `inotify-tools`) serves as the foundation for file system monitoring. A kdb+ function utilizing the C API can wrap this function. Alternatively, the `inotifywait` system command can be employed, albeit with less precision.

## Results
To assess the efficacy of these methods, a series of tests were conducted, each executed multiple times (20) to calculate the average, maximum, and standard deviation of maximal delays in microseconds. The number of kdb+ workers equaled the system's core count and were pinned to separate cores via [taskset](https://man7.org/linux/man-pages/man1/taskset.1.html).

### Azure VM

Specification:
   * Standard D4ds v4 (4 vCPUs, 16 GiB memory).
   * Command `Inotifywait` used a local ephemeral disk for synchronization.
   * Worker nr: 4

Run 1:

method|medium|average|maximum|deviation
| --- | --- | ---: | ---: | ---: |
each async timer|cpu|1|2|1
peach handles|uds|6|70|15
peach sync|uds|13|23|6
peach sync|tcp|17|57|20
peach handles|tcp|34|191|37
async InotifyWait|file|35|165|40
each async|tcp|39|99|16
peach one-shot|uds|49|630|136
peach one-shot|tcp|70|615|127
each async flush|tcp|73|497|99
async broadcast flush|tcp|91|827|170
each deferred|tcp|757477|757669|179


Run 2:

method|medium|average|maximum|deviation
| --- | --- | ---: | ---: | ---: |
each async timer|cpu|1|2|0
peach handles|uds|8|21|6
peach sync|uds|13|27|7
peach sync|tcp|16|50|15
peach one-shot|uds|41|390|91
each async|tcp|44|118|22
peach one-shot|tcp|66|232|64
async broadcast flush|tcp|69|347|65
each async flush|tcp|88|774|158
async InotifyWait|file|397|7345|1594
peach handles|tcp|588|11061|2403
each deferred|tcp|757201|757307|82

## HPE DL385

Specification:
   * Processors:  (2) AMD EPYC 7763 processors (2.45 GHz), 128 cores
   * Memory:  (32) 128 GiB quad rank DDR4-3200 DIMMs

### Worker nr: 4

Run 1:

method|medium|average|maximum|deviation
| --- | --- | ---: | ---: | ---: |
each async timer|cpu|0|0|0
peach handles|uds|4|6|1
peach sync|tcp|20|49|10
peach one-shot|tcp|23|47|8
each async|tcp|27|33|4
peach one-shot|uds|33|339|71
each async flush|tcp|34|40|3
peach sync|uds|34|277|56
async broadcast flush|tcp|36|45|4
peach handles|tcp|41|267|52
each deferred|tcp|755951|756028|107

Run 2:

method|medium|average|maximum|deviation
| --- | --- | ---: | ---: | ---: |
each async timer|cpu|0|0|0
peach handles|uds|4|6|1
peach one-shot|tcp|6|11|3
peach sync|tcp|8|18|3
peach sync|uds|18|30|7
peach one-shot|uds|19|281|60
each async|tcp|29|39|6
peach handles|tcp|29|37|6
async broadcast flush|tcp|33|40|3
each async flush|tcp|45|226|42
each deferred|tcp|756093|756153|72

### Worker nr: 128

Run 1:

method|medium|average|maximum|deviation
| --- | --- | ---: | ---: | ---: |
each async timer|cpu|1|2|0
peach sync|uds|630|2154|629
peach handles|uds|795|3015|830
peach sync|tcp|942|8478|1837
peach one-shot|tcp|1635|3260|1045
peach one-shot|uds|2493|5078|835
peach handles|tcp|2516|4999|751
each async flush|tcp|3409|11316|2543
each async|tcp|3483|13956|3394
async broadcast flush|tcp|3791|13481|3461
each deferred|tcp|32013787|32015348|1248

Run 2:

method|medium|average|maximum|deviation
| --- | --- | ---: | ---: | ---: |
each async timer|cpu|1|2|1
peach sync|uds|587|1591|517
peach handles|uds|775|3963|942
peach sync|tcp|1108|7144|1616
peach one-shot|tcp|1714|4215|1308
peach one-shot|uds|2193|4264|990
peach handles|tcp|2505|4623|888
each async flush|tcp|2986|11150|1983
async broadcast flush|tcp|3196|12482|2213
each async|tcp|3296|14126|2557
each deferred|tcp|32014930|32016046|868

## Conclusions

The timer-based solution offers unparalleled synchronization, yet it maintains CPUs in an active state until function execution starts. Selecting the optimal trigger time requires meticulous consideration, accounting for hardware specifications and network latency. For applications demanding utmost precision, this method stands as the optimal choice.

Following closely is the `peach` approach employing synchronous messages, securing its position as a formidable contender—given that a dedicated thread can be assigned to each worker. However, it's noteworthy that this approach is unsupported in kdb+ 4.1. peach handlers exhibit commendable speed, though it necessitates the function's presence on both the controller and worker instances.

For a trifecta of convenience, safety, and efficiency, the employment of one-shot requests emerges as a viable solution. This approach ensures expedient execution, all while circumventing potential pitfalls encountered in other methods.

