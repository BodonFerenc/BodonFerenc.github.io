---
layout: post
title:  "Lists - Python and Q side-by-side"
date:   2018-09-02
categories: kdb+ tutorial
tags: kdb,q,python,pandas,numpy
---

[Python](https://www.python.org/) and [Q](https://code.kx.com/v2/learn/q-for-all/) are two world-class, dynamic programming languages with many similarities and some interesting differences. Python is a general language with specialized libraries for different fields like web and mobile development or data analysis. Q is primarily used in the financial industry for data analysis and developing trading algorithms. On the Wall Street people often use these tools side-by-side, sporadically with [R](https://www.r-project.org/) and [Matlab](https://www.mathworks.com/products/matlab.html).The symbioses of Python and Q developers demanded new tools to bridge the gap. Q users can import [embedPy](https://github.com/KxSystems/embedPy) to call Python functions which opens the world to a rich set of machine learning algorithms. Python fans can experience the performance gain of Q by loading [PyQ](https://github.com/KxSystems/pyq) and bringing the Python and Q interpreters into the same process so that code written in either of the languages operates on the same data. Libraries embedPy and PyQ reduce integration costs by offering two languages in one interpreter. Still, to become a successful developer, you need to know what expression corresponds to your codeline in the other language. This article helps you with this.

The list is the most fundamental data structure in programming. **In this article, I will compare how the two languages handle lists.** This comparison is useful for Q programmers who would like to pick up Python and play with e.g. built-in machine learning algorithms. Python developers will also benefit from the comparison especially if they are interested in making good money and finding a job in the financial industry where data warehouses are often built on top of Q/Kdb+.

Read the full article on [LinkedIn](https://www.linkedin.com/pulse/lists-python-q-side-by-side-ferenc-bodon-ph-d-/).