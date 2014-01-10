drop table test_lob purge;


-- version 1 - lob test
create /*# or replace echo debug */ table test_lob(
  id number not null,
  z number,
  s  clob,
  b  clob
);

truncate table test_lob;

insert /*+ append */ into test_lob
select rownum, null, dbms_random.string('L',10000), dbms_random.string('x',10000)
  from dual
   connect by level <= 100;
   
   
-- version 1 - lob test, alter table move

create /*# or replace echo debug  */ table test_lob(
  id number not null,
  z  number,
  s  clob,
  b  clob 
)
lob (s) store as basicfile (tablespace tb1 enable storage in row chunk 16K cache),
lob (b) store as securefile (tablespace tb2 retention max keep_duplicates compress medium)
;




-- version 1 - part lob test
create /*# or replace echo debug*/ table test_lob(
  id number not null,
  n  number(10), --#=1
  s  clob,
  b  clob
)
lob (s) store as basicfile (tablespace tb1 disable storage in row chunk 32K cache),
lob (b) store as securefile (tablespace tb2 retention max keep_duplicates compress medium)
partition by list(id)  
  subpartition by hash(n)  
    subpartition template (
      subpartition SP1 tablespace tb1 lob(s) store as SP1_S (tablespace tb2) lob(b) store as SP1_B,
      subpartition SP2 tablespace tb1 lob(s) store as SP2_S (tablespace tb2) lob(b) store as SP2_B, 
      subpartition SP3 tablespace tb1 lob(s) store as SP3_S (tablespace tb2) lob(b) store as SP3_B (tablespace TB1),
      subpartition SP4 tablespace tb1 lob(s) store as SP4_S (tablespace tb1) lob(b) store as SP4_B (tablespace tb1)     
    )  
(partition p1 values(100),
 partition p2 values(200),
 partition p_def values(default)
   lob (b) store as basicfile (tablespace tb2 chunk 16K PCTVERSION 15)
);

 

   
