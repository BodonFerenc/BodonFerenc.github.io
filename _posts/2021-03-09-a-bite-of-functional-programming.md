---
layout: post
title:  "A bite of functional programming and distributed computing"
date:   2021-03-09
tags: kdb q cloud functional-programming distributed-computing
toc: true
---

The first function that you learn on your way to the functional programing world is [map](https://en.wikipedia.org/wiki/Map_(higher-order_function)). It applies a unary/monadic function to each element of a list and returns the list of results.

```python
>>> list(map(sum, [[1,5], [4,2,-2]]))
[6, 4]
```

In [q/kdb+](https://code.kx.com/q/) this is an [iterator](https://code.kx.com/q/ref/iterators/) and called [each](https://code.kx.com/q/ref/each/).

```q
q) sum each (1 5;4 2 -2)
6 4
```

Iterator [each-left](https://code.kx.com/q/ref/maps/#each-left-and-each-right) (denoted by `\:`) is something similar and comes handy if you have a dyadic function - like concatenation - and you would like to fix the second parameter and pass each element of a list as the first parameter

```q
q) ("Jack"; "Linda"; "Steve") ,\: ", how are you today?"
"Jack, how are you today?"
"Linda, how are you today?"
"Steve, how are you today?"
```

Combining `each` with [dot](https://code.kx.com/q/ref/apply/#index) (aka. [indexing at depth](https://code.kx.com/q4m3/6_Functions/#653-indexing-at-depth)) allows you iterating over list of tuples and passing each element of the tuple as a separate parameter to a multivalence function.

```q
// splits a sentence by a separator then takes the nth word
q) splitNtake: {[sep; s; n] vs[sep;s] n}
q) splitNtake[" "; "We are hiring!"; 2]
"hiring!"
q) l: ((","; "foo,bar,baz"; 2); (" "; "hello world"; 0))   // list of triples
q) (splitNtake .) each l
"baz"
"hello"
```
## peach

If you start your q process with secondary threads (by [-s](https://code.kx.com/q/basics/cmdline/#-s-secondary-threads) command line parameter) on a multi-core computer then you can use function [peach](https://code.kx.com/q/ref/each/) instead of `each`. `peach` executes the monadic function in parallel. Furthermore, if you have multiple standalone q processes then you can instruct `peach` to delegate the tasks to the q processes. All you need is assigning the list of process handlers to variable [.z.pd](https://code.kx.com/q/ref/dotz/#zpd-peach-handles). Very simple!

The q processes can live on different hosts and these worker processes can start in multi-threaded mode to leverage inherent parallelization of q. This is particularly useful in today's cloud environments where virtual machines (VM) are easy to allocate and VMs access to the same high performant block storage (like Persistent disks in Google Cloud and multi attach-EBS in AWS) or network storage. If you have an end-of-day work then you start up a large pool of hosts with hundreds of q processes to work parallel. Once the work is done you can rid of your infrastructure resources.

Let us assume that you started the same number of q process on the same port range (variable `ports` of type string list) on a few machines (variable `hosts`). You can use function [cross](https://code.kx.com/q/ref/cross/) to get the cartesian product of hosts and ports

```q
.z.pd: `u#hopen each `$hosts cross ports;
```

Function `peach` assigns the tasks sequentially to the processes then maintains a queue and assigns the task to the process that completed first. This algorithm is demonstrated by the following simple script:

```bash
# start five standalone worker q processes on ports ranging from 5000 to 5004
$ for i in {5000..5004}; do q -p $i </dev/null &> log-$i.log &; done
$ q -s -5
```

```q
q) .z.pd: `u#hopen each 5000 + til 5
q) // execute tasks that make the worker process
q) // sleep for a random short time then returns the worker's PID
q) group {system "sleep ", x; .z.i} peach string 20?.1
62643| 0 6 15
62644| 1 10 13 17
62645| 2 9 11 19
62646| 3 7 12 14 18
62647| 4 5 8 16
```

If the number of tasks is smaller than the number of processes then cross-based assignment of `.z.pd` might be inefficient. You may observe that some hosts are sweating and some hosts are just twiddling their thumbs.

Function `cross` takes the first element of the first list and concatenates with all elements of the second list. Next, it repeats this with the second element of the first list. So your result looks like  `host1:port1`, `host1:port2`, `host1:port3`, ... `host2:port1`, `host2:port2`, `host2:port3`, ...

You need to iterate the other way to get the cartesian product. Fix the port and iterate over the hosts, then take another port and iterate over the hosts again. To achieve this you just need to recall that function cross is semantically equivalent to calling `each-right` on `each-left` then flattening the result, i.e.

```q
{raze x,/:\:y}
```

If you change the order of each-left and each-right, i.e.

```q
.z.pd: `u#hopen each `$raze hosts ,\:/: ports;
```

then you achieve a more balanced load distribution. Tasks are distributed on the hosts fairly when the input list is short.

Task delegation to processes assumes that the worker q processes are identical and either process is able to execute the task. This is not always the case there might be pools of q processes, each pool having its own responsibility. This is typical with horizontal partitioning of tables when data is distributed into shards therefore the each q process has visibility only to a subset of the data. q is famous for its database layer [kdb+](https://code.kx.com/q4m3/14_Introduction_to_Kdb%2B/) that can execute sql-like queries on on-disk or in-memory tables.

There are high performant network storage option available in many public clouds, however, the best performance is still achieved with locally attached SSDs or with [Intel Optane](https://code.kx.com/q/kb/optane/). Queries are often easy to rewrite by employing map-reduce to support horizontal partitioning of the data. To send a task to a specific pool of q workers we can employ two techniques, called one-shot requests and socket sharding.

## One-shot requests

The monadic function that runs by `peach` has certain limitations. It cannot use an open socket to send a message. [One-shot](https://code.kx.com/q/basics/ipc/#sync-request-get) messages come to our rescue. A one-shot request opens a connection, sends a synchronous request and closes the connection. In example below we send a one-shot request to a q process at `myhost:port` where dyadic function [fibonacci](https://code.kx.com/q4m3/1_Q_Shock_and_Awe/#112-example-fibonacci-numbers) is defined.

```q
q) `:myhost:myport (`fibonacci; 5; 1 1)
1 1 2 3 5 8 13
```

If you have a map (or a function) that returns a q address for a given task then we can distribute tasks to specific q processes by starting the main q process with multiple threads (`-s` command line parameter with positive number). In example below our table `t` is horizontally partitioned by date and we would like to get all rows from `t` for a given date, stock pairs. Variable `m` maps dates to q addresses.

```q
({m[x] ({select from t where date=x, stock=y}; x; y)}. ) peach flip (2021.01.26 2020.02.24 2018.09.20; `GOOG`IBM`MSFT)
```

Now, let's scale further and have a pool of processes instead of a solitary q process.

## Socket sharding

[Socket sharding](https://code.kx.com/q/wp/socket-sharding/) on Linux boxes allow multiple q processes to use the same port. Simply prepend literal `rp,` to the port number. The Linux kernel takes care of distributing the task to the processes. The kernel tries to evenly distribute the task but it doesn't do it as efficiently as q. It can easily assign a task to a busy process  while other processes are free. This is demonstrated by the following code.

```bash
$ for i in {1..5}; do q -p rp,5000 </dev/null &> log-$i.log &; done
$ q -s 5
```

```q
q) group {`::5000 ({system "sleep ", x; .z.i}; x)} peach string 20#.1
64683| 0 2 6 7 11 15
64686| 1 3 10
64684| 4 5 12 14 16 18 19
64685| 8 13
64687| 9 17
```

We can see that processes with PIDs 64683 and 64686 received the first two tasks and the third task was assigned again to 64683 although three q processes were free and waiting for work to do.

To summary, parallel one-shot requests with socket sharding falls behind `.z.pd`- based approach in two aspects. First, every request has extra cost of opening and closing a connection. Second, q makes sure that it assigns a task to a free process if there is any. Linux kernel does not guarantee this efficiency. On the other hand `.z.pd`-based approach has a limitation that all worker processes are handled uniformly.

To scale from a pool of q workers on the same host to a pool on multiple hosts we can use TCP load balancers offered by all cloud providers. You don't need any development to scale your infrastructure. Furthermore we can make use of autoscaling feature of the load balancers and start up new hosts with pools of q processes. All these do not require writing a single line of q code.

