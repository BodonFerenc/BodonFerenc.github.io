---
layout: post
title:  "Transferring data between BigQuery and kdb+"
date:   2019-11-25
categories: kdb+ tutorial
tags: kdb,q,BigQuery,interoperability,GCP
---

[Kdb+](https://code.kx.com/q/) and [BigQuery](https://cloud.google.com/bigquery/) are two widely used, robust and popular database systems. BigQuery is a fully managed, massively parallel, cloud database solution created by Google. It is built into the [Google Cloud Platform (GCP)](https://cloud.google.com/). Kdb+ is a high-performance time-series data store, famous for its powerful query language [q](https://code.kx.com/q4m3/) that makes analyzing very large time-series datasets extremely efficient. Kdb+ supports vector operations, functional programming and tables are first-class citizens within the q language.

In this article, you will learn how to transfer data between kdb+ and BigQuery in both directions. You might want to do this because a source of data you wish to ingest into kdb+ is held in BigQuery and your time-series analytics uses kdb+ with your business logic encoded in the q language. For example, in BigQuery, the query language it offers is verbose and therefore difficult to maintain. In q, the queries are often simpler and an order of magnitude smaller in complexity. Kdb+ also allows you to decouple business logic from the underlying data. In BigQuery expressions, the tables and column names are hardcoded. Kdb+ is fully dynamic, meaning that anything can be a parameter even the operators of a query.

On the other hand, you might want to upload kdb+ data to BigQuery for backup purposes or for sharing with another application stack, by employing the elaborated access management that the Google Cloud Platform offers. Kdb+ users can already host their kdb+ solutions in the public cloud and this includes GCP. If you are evaluating and discovering the tools and options available within GCP, one of the tools often introduced by Google is BigQuery. This article helps our users understand how to interoperate with BigQuery.

At the moment there is no BigQuey client library for kdb+ but you can easily transfer data to and from BigQuery indirectly by a transfer layer. There are multiple options for transfer layers, including CSV, JSON, embedPy and Parquet, we will take a closer look on their pros and cons.

Read the whole post on the [Kx blog site](https://kx.com/blog/transferring-data-between-bigquery-and-kdb/).