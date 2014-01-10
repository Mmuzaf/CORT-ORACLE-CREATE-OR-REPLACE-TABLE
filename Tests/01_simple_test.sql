-- simple heap organized table test

exec cort_pkg.set_param_value('echo','false')
exec cort_pkg.set_param_value('debug','false')

drop table simple_table purge;

--version 1
CREATE /*# OR REPLACE echo */ TABLE simple_table(
  col1   NUMBER,
  col2   VARCHAR2(100),
  col3   DATE
)
;

-- sample data
INSERT /*+ append */ INTO simple_table(col1, col2, col3)
SELECT rownum, dbms_random.string('L',20), sysdate - rownum
  FROM DUAL
CONNECT BY LEVEL <= 10000;

COMMIT;

--version 2: alter table
CREATE /*# OR REPLACE echo */ TABLE simple_table(
  col1   NUMBER  NOT NULL,
  col2   VARCHAR2(100)  DEFAULT 'Simple test',
  col3   TIMESTAMP,
  col4   CLOB
)
;

--version 3: insert new column
CREATE /*# OR REPLACE echo */ TABLE simple_table(
  col0   NUMBER  NOT NULL,  --#=MOD(rownum,25)+1
  col1   NUMBER  NOT NULL,
  col2   VARCHAR2(100) DEFAULT 'Simple test',
  col3   TIMESTAMP,
  col4   XMLTYPE
)
COMPRESS
NOLOGGING;

--version 4: change physical attributes
CREATE /*# OR REPLACE echo  */ TABLE simple_table(
  col0   NUMBER  NOT NULL, 
  col1   NUMBER  NOT NULL,
  col2   VARCHAR2(100) DEFAULT 'Simple test',
  col3   TIMESTAMP,
  col4   XMLTYPE
)
PARTITION BY HASH(col0)
  PARTITIONS 8;


--version 5: rename column
CREATE /*# OR REPLACE echo */ TABLE simple_table(
  id     NUMBER  NOT NULL, --#=col0
  col1   NUMBER  NOT NULL,
  col2   VARCHAR2(100) DEFAULT 'Simple test',
  col3   TIMESTAMP,
  col4   XMLTYPE
)
PARTITION BY HASH(id)
  PARTITIONS 8;
  
--version 5.1: smart rename 
CREATE /*# OR REPLACE echo */ TABLE simple_table(
  idxx   NUMBER  NOT NULL, 
  col1   NUMBER  NOT NULL,
  col2   VARCHAR2(100) DEFAULT 'Simple test',
  col_3   TIMESTAMP,
  col_4   XMLTYPE
)
PARTITION BY HASH(idxx)
  PARTITIONS 8;

--version 5.2: smart rename 
CREATE /*# OR REPLACE echo */ TABLE simple_table(
  id     NUMBER  NOT NULL, 
  col1   NUMBER  NOT NULL,
  col2   VARCHAR2(100) DEFAULT 'Simple test',
  col3   TIMESTAMP,
  col4   XMLTYPE
)
PARTITION BY HASH(id)
  PARTITIONS 8;

--version 6: new column
CREATE /*# OR REPLACE echo no_debug */ TABLE simple_table(
  id     NUMBER  NOT NULL, 
  col1   NUMBER  NOT NULL,
  col2   VARCHAR2(100) DEFAULT 'Simple test',
  zzzz   date,
  col3   TIMESTAMP,
  col4   XMLTYPE
)
PARTITION BY HASH(id)
  PARTITIONS 8;
  






