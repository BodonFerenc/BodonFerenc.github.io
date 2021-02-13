/ 2020.06.20T12:41:23.360 fbodon-macbook.local fbodon
/ q trees2015.load.q FILE [-bl|bulkload] [-bs|bulksave] [-co|compress] [-js|justsym] [-exit] [-savedb SAVEDB] [-saveptn SAVEPTN] [-savename SAVENAME] [-chunksize NNN (in MB)] 
/ q trees2015.load.q FILE
/ q trees2015.load.q
/ q trees2015.load.q -chunksize 11 / test to find optimum for your file
/ q trees2015.load.q -savedb DB -saveptn PTN -savename NAME / to save to `:DB/PTN/NAME/
/ q trees2015.load.q -savedb taq -saveptn 2008.04.01 -savename trade / to save to `:taq/2008.04.01/trade/
/ q trees2015.load.q -help
FILE:LOADFILE:`$":trees2015.csv"
o:.Q.opt .z.x;if[count .Q.x;FILE:hsym`${x[where"\\"=x]:"/";x}first .Q.x]
if[`help in key o;-1"usage: q trees2015.load.q [FILE(default:trees2015.csv)] [-help] [-bl|bulkload] [-bs|bulksave] [-js|justsym] [-savedb SAVEDB] [-saveptn SAVEPTN] [-savename SAVENAME] [-chunksize NNN (in MB)] [-exit]\n";exit 1]
SAVEDB:`:csvdb
SAVEPTN:`
if[`savedb in key o;if[count first o[`savedb];SAVEDB:hsym`$first o[`savedb]]]
if[`saveptn in key o;if[count first o[`saveptn];SAVEPTN:`$first o[`saveptn]]]
NOHEADER:0b
DELIM:","
\z 0 / D date format 0 => mm/dd/yyyy or 1 => dd/mm/yyyy (yyyy.mm.dd is always ok)
LOADNAME:`trees2015
SAVENAME:`trees2015
LOADFMTS:"DII*HHSSS*SSSSS*SSSSSSSSS*HSHHSHHHS*ISFFFF"
LOADHDRS:`created_at`tree_id`block_id`the_geom`tree_dbh`stump_diam`curb_loc`status`health`spc_latin`spc_common`steward`guards`sidewalk`user_type`problems`root_stone`root_grate`root_other`trnk_wire`trnk_light`trnk_other`brnch_ligh`brnch_shoe`brnch_othe`address`zipcode`zip_city`cb_num`borocode`boroname`cncldist`st_assem`st_senate`nta`nta_name`boro_ct`state`Latitude`longitude`x_sp`y_sp
if[`savename in key o;if[count first o[`savename];SAVENAME:`$first o[`savename]]]
SAVEPATH:{` sv((`. `SAVEDB`SAVEPTN`SAVENAME)except`),`}
LOADDEFN:{(LOADFMTS;$[NOHEADER;DELIM;enlist DELIM])}
PRESAVEEACH:{x}
POSTLOADEACH:{update spc_latin:lower spc_latin,spc_common:lower spc_common from x}
POSTLOADALL:{update root_stone:root_stone=`Yes,root_grate:root_grate=`Yes,root_other:root_other=`Yes,trnk_wire:trnk_wire=`Yes,trnk_light:trnk_light=`Yes,trnk_other:trnk_other=`Yes,brnch_ligh:brnch_ligh=`Yes,brnch_shoe:brnch_shoe=`Yes,brnch_othe:brnch_othe=`Yes from x}
POSTSAVEALL:{x}
LOAD:{[file] POSTLOADALL POSTLOADEACH$[NOHEADER;flip LOADHDRS!LOADDEFN[]0:;LOADHDRS xcol LOADDEFN[]0:]file}
LOAD10:{[file] LOAD(file;0;1+last(11-NOHEADER)#where 0xa=read1(file;0;20000))} / just load first 10 records
JUSTSYMFMTS:"      SSS SSSSS SSSSSSSSS  S  S   S  S    "
JUSTSYMHDRS:`curb_loc`status`health`spc_common`steward`guards`sidewalk`user_type`root_stone`root_grate`root_other`trnk_wire`trnk_light`trnk_other`brnch_ligh`brnch_shoe`brnch_othe`zip_city`boroname`nta`state
JUSTSYMDEFN:{(JUSTSYMFMTS;$[NOHEADER;DELIM;enlist DELIM])}
CHUNKSIZE:4194000
DATA:()
if[`chunksize in key o;if[count first o[`chunksize];CHUNKSIZE:floor 1e6*1|"I"$first o[`chunksize]]]
COMPRESS:any`co`compress in key o
COMPRESSZD:17 2 6
if[COMPRESS;.z.zd:COMPRESSZD]
k)fs2:{[f;s]((-7!s)>){[f;s;x]i:1+last@&0xa=r:1:(s;x;CHUNKSIZE);f@`\:i#r;x+i}[f;s]/0j}
disksort:{[t;c;a]if[not`s~attr(t:hsym t)c;if[count t;ii:iasc iasc flip c!t c,:();if[not$[(0,-1+count ii)~(first;last)@\:ii;@[{`s#x;1b};ii;0b];0b];{v:get y;if[not$[all(fv:first v)~/:256#v;all fv~/:v;0b];v[x]:v;y set v];}[ii]each` sv't,'get` sv t,`.d]];@[t;first c;a]];t}
BULKLOAD:{[file] fs2[{`DATA insert POSTLOADEACH$[NOHEADER or count DATA;flip LOADHDRS!(LOADFMTS;DELIM)0:x;LOADHDRS xcol LOADDEFN[]0: x]}file];count DATA::POSTLOADALL DATA}
SAVE:{(r:SAVEPATH[])set PRESAVEEACH .Q.en[`. `SAVEDB] x;POSTSAVEALL r;r}
BULKSAVE:{[file] .tmp.bsc:0;fs2[{.[SAVEPATH[];();,;]PRESAVEEACH t:.Q.en[`. `SAVEDB]POSTLOADEACH$[NOHEADER or .tmp.bsc;flip LOADHDRS!(LOADFMTS;DELIM)0:x;LOADHDRS xcol LOADDEFN[]0: x];.tmp.bsc+:count t}]file;POSTSAVEALL SAVEPATH[];.tmp.bsc}
JUSTSYM:{[file] .tmp.jsc:0;fs2[{.tmp.jsc+:count .Q.en[`. `SAVEDB]POSTLOADEACH$[NOHEADER or .tmp.jsc;flip JUSTSYMHDRS!(JUSTSYMFMTS;DELIM)0:x;JUSTSYMHDRS xcol JUSTSYMDEFN[]0: x]}]file;.tmp.jsc}
if[any`js`justsym in key o;-1(string`second$.z.t)," saving `sym for <",(1_string FILE),"> to directory ",1_string SAVEDB;.tmp.st:.z.t;.tmp.rc:JUSTSYM FILE;.tmp.et:.z.t;.tmp.fs:hcount FILE;-1(string`second$.z.t)," done (",(string .tmp.rc)," records; ",(string floor .tmp.rc%1e-3*`int$.tmp.et-.tmp.st)," records/sec; ",(string floor 0.5+.tmp.fs%1e3*`int$.tmp.et-.tmp.st)," MB/sec; CHUNKSIZE ",(string floor 0.5+CHUNKSIZE%1e6),")"]
if[any`bs`bulksave in key o;-1(string`second$.z.t)," saving <",(1_string FILE),"> to directory ",1_string` sv(SAVEDB,SAVEPTN,SAVENAME)except`;.tmp.st:.z.t;.tmp.rc:BULKSAVE FILE;.tmp.et:.z.t;.tmp.fs:hcount FILE;-1(string`second$.z.t)," done (",(string .tmp.rc)," records; ",(string floor .tmp.rc%1e-3*`int$.tmp.et-.tmp.st)," records/sec; ",(string floor 0.5+.tmp.fs%1e3*`int$.tmp.et-.tmp.st)," MB/sec; CHUNKSIZE ",(string floor 0.5+CHUNKSIZE%1e6),")"]
if[any`bl`bulkload in key o;-1(string`second$.z.t)," loading <",(1_string FILE),"> to variable DATA";.tmp.st:.z.t;BULKLOAD FILE;.tmp.et:.z.t;.tmp.rc:count DATA;.tmp.fs:hcount FILE;-1(string`second$.z.t)," done (",(string .tmp.rc)," records; ",(string floor .tmp.rc%1e-3*`int$.tmp.et-.tmp.st)," records/sec; ",(string floor 0.5+.tmp.fs%1e3*`int$.tmp.et-.tmp.st)," MB/sec; CHUNKSIZE ",(string floor 0.5+CHUNKSIZE%1e6),")"]
if[`exit in key o;exit 0]
/ DATA:(); BULKLOAD LOADFILE / incremental load all to DATA
/ BULKSAVE LOADFILE / incremental save all to SAVEDB[/SAVEPTN]
/ DATA:LOAD10 LOADFILE / only load the first 10 rows
/ DATA:LOAD LOADFILE / load all in one go
/ SAVE LOAD LOADFILE / save all in one go to SAVEDB[/SAVEPTN]
