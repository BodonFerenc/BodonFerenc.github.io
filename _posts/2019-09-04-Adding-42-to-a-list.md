---
layout: post
title:  "Adding 42 to a list"
date:   2019-09-04
category: Office Life
tags: python c java kdb numpy R Matlab functional-programming vectorprogramming
---

The Company ColorCode LTD truly believes in inclusion and diversity and lets their developers decide which programming language they wish to use.

![Adding 42 to a list](/assets/fortytwo/cover_dev_to.jpg)


Jack is a C programmer and has been assigned to an ad-hoc task of transferring some data. He quickly puts together a Python script in which he adds 42 to all elements of list _l_.

```
>>> res = []
>>> for i in range(len(l)):
      res.append(l[i] + 42)
```

His desk neighbor draws Jack's attention to the [for-each](https://docs.python.org/3/tutorial/controlflow.html#for-statements) concept which is supported natively by Python. Jack simplifies his script and merges it into the master branch of the Git repo.

```
>>> res = []
>>> for e in l:
      res.append(e + 42)
```

Brina, an intermediate Python programmer, spots the commit and visits Jack to show her favorite Python feature, [list comprehension](https://docs.python.org/3/tutorial/datastructures.html#list-comprehensions).

```
>>> res = [e + 42 for e in l]
```
Then Python guru, Xu, joins the conversation. He asks Jack if variable res will be modified later. If not, then he recommends using a tuple and generator expression instead of a list. Tuples are faster to create and require less memory than lists.

```
>>> res = tuple(e + 42 for e in l)
```

The Business Continuity Manager, Harry, challenges the group about the generality of list comprehension in other programming languages. Who will maintain the code if Python developers jump on a new hype. Other developers overhear the conversation and join the discussion. The Haskell, Erlang, Perl, Ruby and Scala developers all agree that Jack should use the [higher-order function map](https://en.wikipedia.org/wiki/Map_(higher-order_function)), which is more wide-spread than list comprehension. In fact, most other programming languages also call this function map, so the objective of the code will be obvious for other developers. Harry is satisfied with the consensus.

```
>>> res = list(map(lambda e: e + 42, l))
```

Xu chimes in again and ask if the result should really be a list or can it be a generator. "Let us avoid unnecessary conversions", - he says. Jack cannot really answer this question and accepts Xu's offer to go through the code.

Java developer János listens to the discussion with sadness. He knows that Java 8 encourages functional programming, but he only had a chance to try it at home. At the office he works on a system with more than a million lines of code and the business will not sponsor a migration to the new Java version. Five years ago many outages were caused by migration to Java 6, although they safe-guarded the move with a high number of unit tests and employed a complete QA team.

```
import java.util.List;
import java.util.ArrayList;

// Java 6:
List<Integer> res = new ArrayList<Integer>();

for (Integer e : l):
  res.add(e + 42);


// Java 8:
import java.util.stream.Collectors;

List<Integer> res = l.stream().map(e -> e + 42).collect(Collectors.toList());
```

The other developers feel empathy and try to console János. although he had a oneliner he could save only 7% of the typing.

Shraddha - a Python developer, whose avatar is a librarian - reminds the others to avoid reinventing the wheel. Instead of creating yet another lambda function, simply do a projection from operator plus. The library [functools](https://docs.python.org/3/library/functools.html#partial-objects), together with library [operators](https://docs.python.org/3/library/operator.html), support this.

```
>>> from functools import partial
>>> from operator import add

>>> res = list(map(partial(add, 3), l))
```

Shraddha loves the partial function. She admits that she was influenced by the [Q programming language](https://code.kx.com/q4m3/) in which the partial function ([projection](https://code.kx.com/q4m3/6_Functions/#64-projection) in Q parlance) is nicely built into the core language.

```
q) 2 + 3           // infix notation
5
q) +[2; 3]         // prefix notation
5
q) addTwo: +[2]    // fix the first parameter
q) addTwo[3]
5
```

Yiorgos, the fan of object-oriented programming, reminds Shraddha that in Python everything is an object and there are some magic methods. The plus operator invokes private method `__add__` behind the scenes.

```
>>> 1.2 + 3.4
4.6
>>> 1.2.__add__(3.4)
4.6
```

The parser requires extra space to do the same with integers

```
>>> 2.__add__(3)
            ^
SyntaxError: invalid syntax
>>> 2 .__add__(3)
5
```

Yiorgos shows how to add 42 to all elements of a list without using lambda functions or importing [functools](https://docs.python.org/3/library/functools.html).

```
res = list(map(42 .__add__, l))     // note the extra space after 42
```

Five data scientists, Arthur, Silvia, Fred, Kiefer and György, experts in Q, Pandas (Python), R, Julia and Matlab respectively, are arriving from a meeting and approach the group. They don't really understand why such a task is an issue for anybody since a decent vector programming language solves this out-of-the-box. Apart from the value assignments all of them write the same code:
```
 l + 42
```

Silvia suggests using Numpy anyway (for variables l and res) because it is simpler to use, faster and requires less memory. She enters into a long and thorough discussion with Xu about the pros and cons of a list, Python array, Numpy array, tuple, generators, etc. Arthur listens confused and does not really understand why there are so many options.

In Q there is only one list and every single Q programmer will perform this task in the same way

```
q) res: l + 42
```
He mentions that somebody knew a guy who heard about somebody who used a do-while loop in Q... - but it is probably just an urban legend.

Fred hijacks the topic and admits that he got confused when he tried to use Matlab and Julia for the first time. Using the + symbol worked fine when adding two vectors element-wise, but produced an error for vector multiplications via the * symbol. György explains that the designers of the vector programming languages need to determine who the primary users are. The * symbol may either refer to the [dot product](https://en.wikipedia.org/wiki/Dot_product) ([matrix multiplication](https://en.wikipedia.org/wiki/Matrix_multiplication) in a general case) or to element-wise multiplication. Data scientists more often use element-wise operations as vectors are derived from columns of data tables. Many other engineers prefer strict matrix operations. Q, Numpy and R targets to first type of users, Matlab and Julia target the other one. Nevertheless, all five programming languages support both operations.

```
# q/kdb+
q) v1 * v2                  # element-wise
q) v1 mmu flip enlist v2    # matrix multiplication
q) v1 wsum v2               # another form for vectors

# Python Numpy
>>> v1 * v2
>>> np.matmul(v1, v2)
>>> np.dot(v1, v2)
>>> np.inner(v1, v2)

# R
> v1 * v2
> v1 %*% v2

# Matlab
v1 .* v2
v1 * v2.'

# Julia
julia> v1 .* transpose(v2)
julia> v1 * v2
```

Isabelle the diversity manager frowns. She worries about the debate and hopes that nobody's feelings will be hurt. She was surprised when she read on LinkedIn that even in software engineering certain decisions are not black or white but debates are often 'religious'. James, the development head, assures her that everything is under control and this is not a debate anyway but rather a brainstorming session with some knowledge sharing.

James is more worried about something else: if there are nine different solutions for this simple task then how many possible solutions exist for a complex problem?!? The number of possible combinations increases exponentially with the increase in complexity.

Deekshant from Quality Management welcomes the discussion. He would like to make sure that people solve this problem consistently going forward. This would lead to a more stable code and faster incident resolution. He asks "Who volunteers to create meeting minutes for this ad-hoc meeting and create a guideline for future reference?". At this point, the group silently dissolves.


_DISCLAIMER. This is a work of fiction. Names, characters, businesses, events, and incidents are either the products of the author’s imagination or used in a fictitious manner. Any resemblance to actual persons or companies is purely coincidental._

_This post was originally published on [LinkedIn](https://www.linkedin.com/pulse/adding-42-list-ferenc-bodon-ph-d-/)._