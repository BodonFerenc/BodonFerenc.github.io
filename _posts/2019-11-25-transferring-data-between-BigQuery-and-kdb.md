---
layout: post
title:  "Transferring data between BigQuery and kdb+"
date:   2019-11-25
categories: kdb+ tutorial
tags: kdb,q,BigQuery,interoperability,GCP
---

[Q/kdb+](https://code.kx.com/v2/) and [BigQuery](https://cloud.google.com/bigquery/) are two widely used, robust and popular database systems. BigQuery is a fully managed, massively parallel, cloud database solution created by Google. It is built into the [Google Cloud Platform (GCP)](https://cloud.google.com/gcp/). kdb+ is a high-performance time-series data store, famous for its powerful query language [q](https://code.kx.com/q4m3/) that makes analyzing very large datasets extremely efficient. kdb+ supports vector operations, functional programming and tables are first-class citizens within the q language.

In this article, you will learn how to transfer data between kdb+ and BigQuery in both directions. You might want to do this because a source of data you wish to ingest into kdb+ is held in BigQuery and your time-series analytics uses kdb+ with your business logic encoded in the q language. For example, in BigQuery,  the query language it offers is verbose and therefore difficult to maintain. In q, the queries are often simpler and an order of magnitude smaller in complexity. kdb+ also allows you to decouple business logic from the underlying data. In BigQuery expressions, the tables and column names are hardcoded. kdb+ is fully dynamic, meaning that anything can be a parameter even the operators of a query.

On the other hand, you might want to upload kdb+ data to BigQuery for backup purposes or for sharing with another application stack, by employing the elaborated access management that the Google Cloud Platform offers. kdb+ users are already host their kdb+ solutions in the public cloud and this includes GCP. If you are evaluating and discovering the tools and options available within GCP, one of the tools often introduced by Google is BigQuery. This article helps our users understand how to interoperate with BigQuery.

For several programming languages like Python, R, Scala (Spark) there is BigQuery client library which allows direct data transfer to and from BigQuery - a simple function call to upload to or download from BigQuery does the job. In kdb+ you need a middleman.

#### Table of contents

1. [Type comparison](#typecomparison)
    * [Complex columns](#complexcolumns)
2. [Transfer formats, interaction](#transferformatsinteraction)
3. [Simple Table](#simpletable)
    * [CSV](#csv)
        - [From BigQuery to kdb+](#frombigquerytokdb)
        - [From kdb+ to BigQuery](#fromkdbtobigquery)
    * [JSON](#json)
        - [From BigQuery to kdb+](#frombigquerytokdb)
        - [From kdb+ to BigQuery](#fromkdbtobigquery)
    * [EmbedPy](#embedpy)
        - [From BigQuery to kdb+](#frombigquerytokdb)
        - [From kdb+ to BigQuery](#fromkdbtobigquery)
    * [Summary](#summary)
4. [Tables with array columns](#tableswitharraycolumns)
    * [CSV](#csv)
        - [From BigQuery to kdb+](#frombigquerytokdb)
        - [From kdb+ to BigQuery](#fromkdbtobigquery)
    * [JSON](#json)
    * [EmbedPy](#embedpy)
5. [Streaming data](#streamingdata)
6. [Conclusion](#conclusion)


## Type comparison
Let us compare the type of a table cell in kdb+ and BigQuery. Python's library Pandas can act as a middleman in the transfer so we include it in the table below.

| type | size | q | BigQuery | Pandas | Comment |
| --- | --- | --- | --- | --- | --- |
| boolean | 1 | boolean | BOOL | bool | literals: kdb+ 1b/0b, BigQuery TRUE/FALSE, Python  True/False |
| integer | 1 | byte | | | |
| | 2 | short | | | |
| | 4 | int | | | |
| | 8 | long | INT64 | int64 | |
| float | 4 | real | | | |
| | 8 | float | FLOAT64 | float64 | |
| | 16 | | NUMERIC |
| character | 1 | char | |
| string | | list of characters | STRING | |
| byte list | | list of bytes | BYTES | |
| symbol | | symbol | | category |
| date | 4 | date | DATE | |
| date-time | 8 | timestamp | DATETIME | datetime64[ns] | Precision: BigQuery microsecond, kdb+ nanosecond |
| time | | time | TIME | | Precision: BigQuery microsecond, kdb+ millisecond |
| minute | | minute | |
| second | | second | |
| date-time with timezone | | | TIMESTAMP | | Precision: BigQuery microsecond |
| span of timestamps | | timespan | | timedelta64[ns] |
| globally unique identifier | 16 | guid | |
| geography | | | GEOGRAPHY |

As we can see there is no one-to-one mapping of all data types. For example, [guids](https://code.kx.com/q4m3/2_Basic_Data_Types_Atoms/#233-guid) are not supported by BigQuery and [geography](https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types#geography-type) type is not supported by q. There are more data types in q so selecting the BigQuery equivalent of a kdb+ data type is very straightforward. Transferring data in the other direction will need more careful consideration. For example, a BigQuery string can be represented by either string or symbol in kdb+. Similarly, BigQuery integer can be a short, an int or a long in kdb+. If type conflict may cause confusion in the reading then we will refer to BigQuery types by capital letters, e.g. TIMESTAMP.

Timestamps support nanosecond precision in kdb+ and Pandas. Also they natively support the timespan data type to represent differences between timestamps.
This simplifies querying and managing data at nanosecond precision, especially for temporal data. Subtracting timestamps in BigQuery returns an INT64 data type which requires the user to manage some of the time centric logic in a more verbose way. For BigQuery, the native time data type is limited to microsecond precision.
Note: kdb+ also uses a `time` datatype which is millisecond precision. As a result, if passing that time data type from BigQuery to kdb+, mapping to timespan can avoid precision loss.

All languages support the notion of null and infinite.

kdb+ and Pandas support [keyed tables](https://code.kx.com/q4m3/8_Tables/#841-keyed-table). BigQuery, CSV and JSON have no such concept. If you would like to transfer a keyed kdb+ table to BigQuery then it will be converted to a normal table automatically in one intermediate step.

### Complex columns
BigQuery and kdb+ extend ANSI SQL in several ways. ANSI SQL only supports tables that contain scalars in all cells. When Kx rolled out q in 2003 complex columns like arrays were also supported for in-memory tables. Initially, you could persist only simple lists, i.e. type of all elements are the same. From version 3.6 you can also persist general columns, e.g. a cell may contain a dictionary or a list of lists.

Google introduced the support of complex columns [in an update to BigQuery](https://cloud.google.com/bigquery/docs/release-notes) in 2016. Array columns can only consist of values of the same type. kdb+ has no such restriction. [Structs](https://cloud.google.com/bigquery/docs/nested-repeated), aka records, are also supported by Google. Structs are containers of ordered fields each with a mandatory type and an optional field name. Structs are a bit similar to dictionaries (aka, maps or key-value stores), although the key set is fixed and the value types need to be set at table creation time. kdb+ offers full flexibility of key-value cells by introducing [anymap](https://code.kx.com/v2/releases/ChangesIn3.6/) in version 3.6. We do not cover struct and anymap types in this document.


## Transfer formats, interaction
BigQuery can export tables into CSV, JSON and Avro. Uploading to BigQuery can also use ORC and Parquet files. kdb+ natively supports CSV and JSON. Recently [kdb+ Parquet libraries](https://github.com/rianoc/qParquet) were released that allows saving and loading Parquet files. In this article, we do not cover transfer based on Parquet files.

BigQuery export and import handle compressed CSV and JSON seamlessly. JSON data must be newline delimited.

You can interact with BigQuery in multiple ways. Beginners typically start with the GCP web interface. It is a user friendly UI that drives the users and restricts options intelligently. For example, on your table page within the BigQuery section, you can select link EXPORT. If the table contains a complex column then an option for CSV conversion is not even offered.

Once people feel comfortable with the basics of BigQuery and other GCP components they start using command line tools. You need to install [Google Cloud SDK](https://cloud.google.com/sdk/docs/) on your local machine to have commands `bq` and `gsutil` at your fingertips.

In code snippets below our sample table is called `t`, the BigQuery project `myProject`, the dataset `myDataset` and the bucket name of the Cloud Storage is `myStorageSpace`.

All source code and examples included in this article are available on [Kx Github](https://github.com/KxSystems) repository. We selected Jupyter notebooks for demonstration as they provide an elegant way to mix comments, source code and output. You need to install [JupyterQ kernel](https://code.kx.com/v2/interfaces/jupyterq/) to run the notebooks locally.

## Simple Table
Let us call a table simple if it does not contain any complex columns. In this section, we take note of the scalar type handling.

### CSV
CSV stands for "comma-separated values". It is a simple file format used to store tabular data. Exporting to CSV is supported by almost all data management systems.

#### From BigQuery to kdb+
BigQuery and kdb+ support importing from and exporting to CSV files.

To transfer data from BigQuery do the following

1. Export the table in CSV to Cloud Storage. You can do this via the BigQuery console web interface or via `bq extract` command.
1. Export CSV from Cloud Storage to local disk. Use either the Storage/Browser web interface or the `gsutil cp` command.
1. Import CSV into q.
1. Clean up temporal files

Any q script can [call system commands](https://code.kx.com/v2/ref/system/) so all four steps can be executed inside a q process. For example, Linux command `ls -l` can run from q by command `system "ls -l"`. For simplicity, we omit this q wrapper.

Example commands are below.

```
$ bq extract --compression GZIP 'myProject:myDataset.t' gs://myStorageSpace/t.csv.gz
$ gsutil cp gs://myStorageSpace/t.csv.gz /tmp/
$ gunzip /tmp/t.csv.gz
```

```
q) t: ("sIF**DTP"; enlist ",") 0: hsym `t.csv
```

```
$ gsutil rm gs://myStorageSpace/t.csv.gz
$ rm /tmp/t.csv
```
The scary `"sIF**DTP"` literal is the type specifier. Letter `s` stands for symbol, `I` for integer, `F` for float, etc.
For automatic schema discovery you can employ [csvutil](https://github.com/KxSystems/kdb/blob/master/utils/csvutil.q) core library. First, you need to load the library

```
q) \l utils/csvutil.q
```

then you can replace the q command with the following.

```
q) t: .csv.read `t.csv
```

There are two other write types supported by BigQuery, write-if-empty and append. You can do the same in kdb+. To append, simply use the comma operator and replace

```
q) t: ...
```

with

```
q) t,: ...
```

Table concatenation with the comma operator requires the tables to have the same schema, i.e. column names and types need to match. If you would like to relax this and allow extra columns then you can use [union join operator `uj`](https://code.kx.com/v2/ref/uj/)

```
q) t: t uj ...
```

New fields of the existing rows will be filled with null values.

Users should be aware of the runtime charges for using BigQuery. In BigQuery the basic concept is that you are charged for the amount of data queried at runtime. In addition you would get normal storage charges for Google Cloud Storage. There are no charges for exporting data from BigQuery, but you do incur charges for storing the exported data in Google Cloud Storage. If you are less sensitive to the network and disk cost then you can omit compression and save some typing.

Going forward we will drop 'myProject' prefix from the `bq` commands and assume that you have access only to a single GCP project.

##### Size Limitations, wildcards, file streaming
1 GB is the [maximum size of data you can export from BigQuery](https://cloud.google.com/bigquery/docs/exporting-data) to Cloud Storage. This refers to the input data size, not the output file size. You will fit into 1 GB if your table contains a few million rows and a few columns.

You can check the table size on the console web interface (`Table Info` / `Table Size`) or by running
```
$ bq show myProject:myDataset.t
```
and checking column `Total Bytes`.


Copying 1GB from BigQuery and storing that to Google Cloud Storage may be slower than you might expects. In this example, it took 3 minutes and 17 seconds to execute for 22M rows. Note that these timings are very distinct from query runtimes observed from BigQuery.

`bq extract` and `gsutil` supports wildcards if the table is larger than 1 GB. In q you can read each CSV file, convert to a table and concatenate.
```
$ bq extract --compression GZIP 'myDataset.t' gs://myStorageSpace/t-*.csv.gz
$ gsutil cp gs://myStorageSpace/t-*.csv.gz /tmp
$ gunzip /tmp/t-*.csv.gz
```

```
q) t: raze {("sIF**DTP"; enlist ",") 0: hsym x} each `$system "ls /tmp/t-*.csv"
```
and with automatic schema discovery
```
q) t: raze .csv.read each `$system "ls /tmp/t-*.csv"
```

You can save memory by using pipes and stream processing. This is handy for multiple zipped files. Instead of unzipping the compressed file just unzip it into a pipe and use [.Q.fps](https://code.kx.com/v2/kb/named-pipes/). The first rows will be treated as data columns so you need to ask BigQuery not to put column names into the first rows (option [--noprint_header](https://cloud.google.com/bigquery/docs/reference/bq-cli-reference#bq_extract)). Since column names are not available in the CSV files, you need to create an empty table manually.

```
$ bq extract --compression GZIP --noprint_header 'myDataset.t' gs://myStorageSpace/t-*.csv.gz
$ gsutil cp gs://myStorageSpace/t-*.csv.gz /tmp
$ rm -f fifo && mkfifo fifo
$ gunzip -c t-*.csv.gz > fifo &
```

```
q) columnTypes: "sIF**DTP"
q) t: flip `symCol`intCol`floatCol`stringCol`tsCol`dateCol`timeCol`timestampCol!columnTypes$\:()
q) .Q.fps[{`t insert (columnTypes; ",")0:x}]`:fifo
```
##### Type issues
Manual casting is needed for BigQuery's BOOLEAN columns

```
q) BQToKdbBoolMap: ("true";"false")!10b
q) update BQToKdbBoolMap boolColumn from t
```

and TIMESTAMP columns

```
q) update "P"$-4_/:tsCol from t
```

we chopped off " UTC" postfix from the timestamp string column. This applies to both manual and `csvutil` based CSV import.

##### Location Limitations
The BigQuery data and the Cloud Storage need to be located in the same GCP region. For example, you cannot export a BigQuery table from the US into storage in the EU. There is a GCP option for [Geo-redundant](https://cloud.google.com/storage/docs/key-terms#geo-redundant) data, i.e. stored in multi-region or in dual region, gives you more flexibility, but this entails a higher storage price.


#### From kdb+ to BigQuery
Transferring kdb+ tables to BigQuery is simpler than the other direction, you don't need Cloud Storage as a middleman. With a simple save command, you can export kdb+ table to CSV. You can import this CSV directly to BigQuery. The first step is

```
q) save `t.csv
```

The `save` function handles keyed table, you don't need to [unkey it manually](https://code.kx.com/q4m3/8_Tables/#848-tables-vs-keyed-tables).

In the second step, you can either use the console web interface to the `bq` shell command. The web interface has a size limitation of 10 MB and a row number limitation of 16 000. On the Web Console, click on the dataset and select `Create Table`. Select Upload as the source. A bit misleadingly, even if you would like to append data to an existing table, you need to create a new table with the same name but select `Append to table` as `Write preference` in the `Advanced Options`.

Using the shell console for this is a convenient way of executing this step. This command will append data to the existing table.
```
$ bq load --autodetect myDataset.t t.csv
$ rm t.csv
```

It is possible to append to a table that has extra columns. Use `--schema_update_option=ALLOW_FIELD_ADDITION`.

If you would like to replace an existing table with the new data, just use the `--replace` switch.

##### Type issues

BigQuery schema auto-detection does not convert columns that contain q boolean literals (zero and one) to BOOL columns. They will be integer columns. You need to manually convert `0` and `1` to `false` and `true` literals. Worse, TIMESTAMP strings need to [match the format precisely](https://cloud.google.com/bigquery/docs/schema-detect#timestamps). If the date parts are separated by dots instead of dashes then auto-detect will create a string column instead of a TIMESTAMP.

You can convert the column to BigQuery friendly format either in kdb+ or in BigQuery. In kdb+ you can easily change the schema of a table in-place. In BigQuery you need to create a temporal table.

Let us see how you convert bool and timestamp values in q. Recall that we already set variable `BQToKdbBoolMap` in an earlier section. All we need is a reverse lookup, operator `?` gives us a helping hand.

```
q) update BQToKdbBoolMap?boolColumn from t
```

The date separators in TIMESTAMP values must be dashes. Date and time parts need to be separated by whitespace. So you need to convert value like "2019.11.05D11:06:18.04826900" to "2019-11-05 11:06:18.04826900". Replacing three characters with three others (dash, dash and whitespace) at fixed positions (4, 7 and 10) can be easily achieved by the [general apply function @](https://code.kx.com/q4m3/6_Functions/#685-general-apply-with-dyadic-functions) and [function projection](https://code.kx.com/q4m3/6_Functions/#641-function-projection).

```
q) update @[; 4 7 10; :; "-- "] each string timestampColumn from t
```

### JSON
JSON (JavaScript Object Notation) is an open-standard file format that uses human-readable text to transmit data objects consisting of key–value pairs. You can regard a row of a table as key-value pairs, hence the consideration of JSON. This approach is in-line with kdb+'s philosophy. Although kdb+ is column oriented you can also process a table by list operations, if this results in a simpler and more readable solution.

There is no advantage to JSON for transferring simple tables. CSV provides a more compact representation of the data - you don't need to repeat the column names for each row. Nevertheless, the type conversions are worth investigating.

#### From BigQuery to kdb+
First, we save the table to Cloud Storage as JSON.

```
$ bq extract --destination_format NEWLINE_DELIMITED_JSON 'myDataset.t' gs://myStorageSpace/t.json
```

You can download from Cloud Storage to your local disk with the same `gsutil` command as you download any other files. Once the file is available locally, you can read in and deserialize it with function [.j.k](https://code.kx.com/v2/ref/dotj/#jk-deserialize). Manual casting is not needed for types of FLOAT, STRING and BOOLEAN. Explicit casts are needed for the rest. For example, INT64 (integer) data types are encoded as JSON strings to preserve 64-bit precision.

```
q) formatterMap: (enlist `)!enlist (::)   // Defining formatted map,
                                          // that maps column names to formatter functions.
                                          // default formatter: leave unchanged

q) formatterMap[`intCol]: "I"$
q) formatterMap[`tsCol]: {"P"$-4 _ x}
q) formatterMap[`dateCol]: "D"$
q) formatterMap[`time]Col: "T"$
q) formatterMap[`timestampCol]: "P"$

q) decode: {[fM; j]
  k: .j.k j;
  key[k]!fM[key k]@'value k}
q) t: formatterMap decode/: read0 hsym `t.json;
```

You can see, only the BigQuery TIMESTAMP needs some massaging. Here, we chop off the last four characters, similarly as we did with CSV files.

You can save function `decode` to your local code library, and all you need is to set the formatter map.

#### From kdb+ to BigQuery

The saving table in JSON and uploading to BigQuery works out-of-the-box.
```
q) save `t.json
```

```
$ bq load --autodetect --source_format NEWLINE_DELIMITED_JSON 'myDataset.t' t.json
```

There is one caveat in the automatic type conversion. Timestamp in q corresponds to DATETIME in BigQuery. The TIMESTAMP in BigQuery contains time zone information. BigQuery prefers TIMESTAMP and assumes that the timezones are UTC in the JSON file.

Unfortunately, you cannot control the column order if you chose BigQuery autodetection. The final table will not match the q table wrt. column ordering even if the dictionaries are properly ordered in the JSON file.


### EmbedPy
Open source BigQuery libraries, written by Google, are available for several programming languages including Python. Python and q are good friends. You can use Python libraries from q via library [embedPy](https://code.kx.com/v2/ml/embedpy/userguide/). Nothing prevents you from transferring data from BigQuery using a load job with embedPy and machine learning utility [.ml.df2tab](https://code.kx.com/v2/ml/toolkit/utilities/util/#mldf2tab). Function `.ml.df2tab` converts a pandas DataFrame to a q table. The pandas community created a wrapper library around the official BigQuery library that makes certain operations simpler. It is called [pandas_gbq](https://pandas-gbq.readthedocs.io/en/latest/). It has some [limitations](https://cloud.google.com/bigquery/docs/pandas-gbq-migration#features_not_supported_by_pandas-gbq) nevertheless is still worth investigating as it provides many useful features. You can read a comparison of the two
Python libraries in the [BigQuery documentation repository](https://cloud.google.com/bigquery/docs/pandas-gbq-migration#features_not_supported_by_pandas-gbq)

In this section, we assume that you installed essential libraries

 * [embedPy](https://code.kx.com/v2/ml/setup/)
 * [google-cloud-bigquery](https://cloud.google.com/bigquery/docs/quickstarts/quickstart-client-libraries#client-libraries-install-python)
 * [pandas (0.25.3)](https://pandas.pydata.org/pandas-docs/stable/install.html)

 Furthermore, you are likely to find these libraries useful:

 * [pandas-gbq](https://pandas-gbq.readthedocs.io/en/latest/install.html) - simplified API for DataFrame transfer to and from BigQuery
 * [pyarrow](https://arrow.apache.org/docs/python/install.html) - for uploading tables with complex columns

When using those, you will need to set up authentication credentials and have the environment variable `GOOGLE_APPLICATION_CREDENTIALS` point to it as Google recommends [here](https://cloud.google.com/bigquery/docs/reference/libraries#setting_up_authentication).

Please make sure that you install the latest versions as legacy versions suffered performance and type conversion issues.


#### From BigQuery to kdb+
You can execute the following command in a q session.

```
q) \l p.q              // load embedPy
q) p)from google.cloud import bigquery
q) p)client= bigquery.Client()

q) p)table_ref= client.dataset("myDataset", project="myProject").table("t")
q) p)table= client.get_table(table_ref)
q) p)df= client.list_rows(table).to_dataframe()

q) \l ml/util/util.q   // load useful Machine Learning utilities
q) t: .ml.df2tab .p.get `df
q) p)df.drop(df.index, inplace=True)  # clean up
```

You can also export a subset of a table and the output of any SELECT statement without the need to create a temporal BigQuery table and Cloud Storage file (both may have cost). Similarly, you don't need to clean up the temporal CSV files that pollute your work environment.

```
q) p)sql= "SELECT * FROM `myDataset.t`"
q) p)df= client.query(sql, project="myProject").to_dataframe()
```

Alternatively, you can use library [pandas_gbq](https://pandas-gbq.readthedocs.io/en/latest/) and its function [read_gbq(https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.read_gbq.html)

```
q) p)import pandas_gbq
q) p)df= pandas_gbq.read_gbq(sql, project_id='myProject')
```

##### Type issues
Function `read_gbq` of library `pandas_gbq` breaks without a meaningful error message if the table contains a column of type TIME. DATE columns are converted to [datetime64](https://docs.scipy.org/doc/numpy/reference/arrays.datetime.html) columns that result in timestamp columns in q by function `.ml.df2tab`. You need to convert timestamp to date manually to avoid that situation.

```
q) update `date$dateCol from `t
```

#### From kdb+ to BigQuery
First, we need to convert a kdb+ table into an embedPy object by using the ML utility function [.ml.tab2df](https://code.kx.com/v2/ml/toolkit/utilities/util/#mltab2df), which is the opposite of `.ml.df2tab`.

```
q) .p.set[`df; .ml.tab2df[t]]
```

In the second step, we have two options again. We can use the official BigQuery library. It automatically discovers types except for objects so we need to set types of string, date and time columns manually.

```
q) p)job_config = bigquery.LoadJobConfig(schema=[bigquery.SchemaField("stringCol", "STRING"), \
    bigquery.SchemaField("dateCol", "DATE"), bigquery.SchemaField("timeCol", "TIME")])
q) p)client.load_table_from_dataframe(df, 'myDataset.t', job_config=job_config)
q) p)df.drop(df.index, inplace=True)  # clean up
```


The second option is to use the DataFrame method [to_gbq](https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.DataFrame.to_gbq.html) of [pandas_gbq](https://pandas-gbq.readthedocs.io/en/latest/). You only need to specify the types of date and time manually. This, however, does not necessarily save any typing because you need to specify DATE and TIME columns in a more verbose way.

```
q) p)table_schema = [{'name': 'date', 'type': 'DATE'}, {'name': 'time', 'type': 'TIME'}]
q) p)df.to_gbq('myDataset.t', 'myProject', table_schema=table_schema, chunksize=None, if_exists='append')
```

Keyed tables are converted to indexed DataFrames by `.ml.tab2df` so key information is preserved. The BigQuery Python library converts the index columns to normal columns before it uploads the data to the cloud.

##### Type issues
Function [.ml.tab2df](https://code.kx.com/v2/ml/toolkit/utilities/util/#mltab2df) converts date and time to `datetime64`. BigQuery API requires `datetime.date` and `datetime.time` instead. You have two ways to get from q's date and time to `datetime.date` and `datetime.time` via `.ml.tab2df`.

On the one hand, you can convert date and time values to strings. Function `.ml.tab2df` leaves the string columns intact. Then you can convert string to `datetime.date` and `datetime.time` in the Python layer.

```
q) .p.set[`df; .ml.tab2df[update string dateCol, string timeCol from t]]
q) p)df['dateCol'] = df.apply(lambda row: datetime.strptime(row['dateCol'], "%Y.%m.%d").date(), axis=1)
q) p)df['timeCol'] = df.apply(lambda row: datetime.strptime(row['timeCol'], "%H:%M:%S.%f").time(), axis=1)
```

On the other hand, you can let `.ml.tab2df` convert date and time to `datetime64` and you convert `datetime64` to `datetime.date` and `datetime.time` in Python.

```
q) .p.set[`df; .ml.tab2df[t]]
q) p)df['dateCol']=df.apply(lambda row: datetime.utcfromtimestamp((row['dateCol'] - np.datetime64('1970-01-01')) / np.timedelta64(1, 's')).date(), axis=1)
q) p)df['timeCol']=df.apply(lambda row: datetime.utcfromtimestamp((row['timeCol'] - np.datetime64('1970-01-01')) / np.timedelta64(1, 's')).time(), axis=1)
```

### Summary
The following table summarizes our findings.

| type of the transfer layer | transfer layer | direction | type issues | Cloud Storage usage | manual file cleanup | comment |
| --- | --- | --- | --- | --- | --- | --- |
| text file | CSV/csvutils | BQ -> Kdb+ | boolean, timestamp | yes | yes | simple, small memory footprint via file streaming |
| | | Kdb+ -> BQ | | no | yes | | |
| | JSON | BQ -> Kdb+ | int, timestamp, date, time, datetime | yes | yes | large text files |
| | | Kdb+ -> BQ | | no | yes | column ordering |
| Python client library + embedPy | google.cloud.bigquery | BQ -> Kdb+ | | no | no | stateless transfer, longer initial setup |
| |  | Kdb+ -> BQ | string, date, time | no | no | |
| | pandas_gbq | BQ -> Kdb+ | date, ~~time~~ | no | no | |
| | | Kdb+ -> BQ | date, time | no | no | |

If Cloud Storage is used in your transfer then you may need to manually remove the Cloud Storage bucket and/or objects used to store your work.

## Tables with array columns
Arrays contain a sequence of values of the same type. You can have array columns in BigQuery, and for that you can just set the mode of a column to REPEATED.

In the previous section, we already burnt ourselves with various type conversions. In this section, we stay in the safe zone and work only with string, integer and float types.

### CSV
Neither BigQuery nor kdb+ can save a table into CSV if it contains an array column. Technically, it would be possible to use an alternative separator (e.g. semi-colon) to separate elements of an array but this is not supported natively by either system.

#### From BigQuery to kdb+
BigQuery does not offer exporting to CSV if a table contains a REPEATED column. A simple workaround is to normalize the table in BigQuery using [UNNEST](https://cloud.google.com/bigquery/docs/reference/standard-sql/arrays#flattening-arrays), export it, then denormalize it in q using command [xgroup](https://code.kx.com/v2/ref/xgroup/).

The following table illustrates normalization. The table contains a single row. There are price and a size array cells both contain five elements.

| id | price | size |
| --- | --- | --- |
| FDP | 102.1 102.4 102.4 102.5 102.9 | 5 30 10 70 300 |

The normalization results in a table with five rows. Size at position _i_ belongs to price at position _i_. The relative order of prices and orders may count, it depends on the context.

| id | price | size |
| --- | --- | --- |
| FDP | 102.1 | 5 |
| FDP | 102.4 | 30 |
| FDP | 102.4 | 10 |
| FDP | 102.5 | 70 |
| FDP | 102.9 | 300 |

Transfer via normalization can be expensive since you are creating an internal table, that can be significantly larger than the denormalized one. In our example, literal `FDP` is stored five times in the normalized table.

For simplicity, we omit the compression and cleanup steps within this section.

```
INSERT INTO `myDataset.tempTable`
SELECT id,p,s from `myDataset.t`,
  UNNEST(price) AS p WITH OFFSET pos1,
  UNNEST(size) AS s WITH OFFSET pos2
  WHERE pos1 = pos2
```

```
$ bq extract myDataset.tempTable gs://myStorageSpace/tempTable.csv
$ bq rm myDataset.tempTable
$ gsutil cp gs://myStorageSpace/tempTable.csv /tmp
```

```
q) t: `id xgroup .csv.read `tempTable.csv
```
Note that the two `UNNEST` commands separated by a comma represents a cartesian product. The more array columns the table has, the more `UNNEST` commands are required. The size of the temporal result grows exponentially. For example, if there are ten prices, then BigQuery creates 100 rows then drops 90. Large internal results do not impact pricing but impact performance.

Also, you need to be careful if the order needs to be preserved in the complex column as command `UNNEST` destroys the order of the array elements.

#### From kdb+ to BigQuery

Tables containing complex columns cannot be loaded into BigQuery. We can normalize the table, transfer it and then denormalize it. Instead of `UNNEST` and `xgroup` we need to use [ARRAY_AGG](https://cloud.google.com/bigquery/docs/reference/standard-sql/functions-and-operators#array_agg) and [ungroup](https://code.kx.com/v2/ref/ungroup/).
```
q) tempTable: ungroup t
q) save `tempTable.csv
```

```
$ bq load --autodetect 'myDataset.tempTable' tempTable.csv
```

```
INSERT INTO `myDataset.t`
SELECT id, ARRAY_AGG(price), ARRAY_AGG(size)
FROM `myDataset.tempTable`
GROUP BY id
```

```
$ bq rm myDataset.tempTable
```

It is worth comparing the syntax of q and BigQuery side-by-side.

| action | q | BigQuery |
| --- | --- | --- |
| normalize | `ungroup ta` | <code>SELECT id, price, size from \`ta\`, <br /> UNNEST(price) AS price WITH OFFSET pos1, <br />UNNEST(size) AS size WITH OFFSET pos2 <br />WHERE pos1 = pos2</code> |
| de-normalize | ``` `id xkey t``` | <code>SELECT id, <br />ARRAY_AGG(price), <br />ARRAY_AGG(size) FROM \`t\` <br />GROUP by id</code> |

We can compare the number of characters and words because this relates to developers' productivity and maintenance costs.

| action | statistics | q | BigQuery |
| --- | --- | --- | --- |
| normalize| nr of characters | 8 | 128 |
| | nr of words | 2 | 24 |
| | nr of copy-n-paste | 0 | 6 |
| de-normalize | nr of characters | 6 | 62 |
|  | nr of words | 3 | 11 |
| | nr of copy-n-paste | 0 | 1 |

The nr of copy-n-paste refers to the number of times you need to repeat a literal. For example, you can change the name of your input table easily but to change the column name, you need to modify the BigQuery query at three places.

### JSON
JSON-based transfer handles array columns properly in both directions. The only caveat is that you need to set the type of columns for anything apart from string, float and boolean types.

### EmbedPy
Handling array columns via Python client library works as expected when downloading data from BigQuery, no expensive workaround is needed. The other direction runs into problems.

Function `to_gbq` converts DataFrame to CSV format under the hood so it is not suitable for tables that contain arrays. For this, you need to use the official BigQuery library. Its function [load_table_from_dataframe](https://googleapis.dev/python/bigquery/latest/usage/pandas.html) converts the DataFrame to Parquet format before sending it to the API. Unfortunately, lists are wrapped into RECORDS and the latest version of the Python library does not work as expected.

## Streaming data
Kdb+ by design supports streaming, realtime and historical data analytics. Our users are very familiar with this concept.

kdb+'s recommended streaming platform is the [tick plant](https://kx.com/blog/overview-kdb-tick/). It consists of a pub/sub component called ticker plant (TP). Publishers send data to TP and subscribers that subscribed to certain tables (or just part of the tables) receive row updates. If you wish to create a kdb+ subscriber that acts as a bridge from this TP into BigQuery then the subscriber needs to employ embedPy and call method [tabledata.insertAll](https://cloud.google.com/bigquery/docs/reference/rest/v2/tabledata/insertAll). Alternatively, you can employ other programming languages that have BigQuery client library. All these programming languages, i.e. C#, GO, Java, Node.js, PHP, Python and Ruby also have [q client libraries](https://code.kx.com/v2/interfaces/#kdb-as-server). BigQuery makes real-time updates available for analysis [within a few seconds](https://cloud.google.com/bigquery/streaming-data-into-bigquery#dataavailability). Since bridge latency is not the bottleneck here, we recommend high-level programming languages like Java and Python for this task.

The Python API is simple. An update can be represented by a list, a tuple or by a dictionary. A list of updates is also accepted. To send the update to BigQuery you need to call method `insert_rows` of a [BigQuery client](https://googleapis.dev/python/bigquery/latest/generated/google.cloud.bigquery.client.Client.html).

Ticker plants send updates to real-time subscribers in a table. You can convert this table to pandas DataFrame and use function [insert_rows_from_dataframe](https://googleapis.dev/python/bigquery/latest/generated/google.cloud.bigquery.client.Client.html) to forward it to BigQuery.

## Conclusion
There are multiple ways to transfer data between BigQuery and kdb+. Unfortunately, there is no single solution that outperforms the others.

The CSV-based transfer is simple and memory efficient if file streaming is used. On the flip side it needs manual cleanup of temporal objects. A workaround is needed for boolean and timestamp types if automatic type detection is used via library [csvutil](https://github.com/KxSystems/kdb/blob/master/utils/csvutil.q). CSV-based transfer only handles array columns if the table is exploded (normalized) in the source space then shrank back in the target space.

JSON based transfer can replace CSV based transfer if the table contains complex columns like arrays and dictionaries. Only strings and float are supported by automatic type conversion, you need to set the type of the other columns explicitly.

The embedPy-based solution needs more setup initially, but it is worth the initial investment. The transfers are stateless, two-step processes, but you hold the data in memory twice. All data types and arrays are handled properly in one direction, from BidQuery to kdb+. The other direction struggles with date, time and arrays.

