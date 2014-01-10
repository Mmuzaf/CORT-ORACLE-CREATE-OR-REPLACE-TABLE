CREATE OR REPLACE TYPE vcarray AS VARRAY(1000) OF VARCHAR2(256);
/

CREATE OR REPLACE TYPE test_obj AS OBJECT(
  name varchar2(30),
  value varchar2(4000)
);

CREATE OR REPLACE TYPE test_arr AS TABLE OF test_obj; 

CREATE OR REPLACE TYPE test_varr AS VARRAY(10) OF test_obj; 

alter type test_obj final cascade;

DROP TABLE varray_table purge;

CREATE /*# or replace debug echo */ TABLE varray_table (
  id number, 
  col1 vcarray,
  col2 vcarray,
--  l    clob,
  x    xmltype
)
varray col1 store as basicfile lob col1_lob1
varray col2  SUBSTITUTABLE at all levels store as securefile lob(nocompress);


CREATE /*# or replace debug echo */ TABLE varray_table_swap (
  id number, 
  col1 vcarray,
  col2 vcarray,
  l    clob,
  x    xmltype
)
partition by system
(partition P_DEF)
varray col1 store as basicfile lob
varray col2  SUBSTITUTABLE at all levels store as securefile lob(nocompress);


TRUNCATE TABLE varray_table;

-- generate data
declare 
  v  vcarray := vcarray();
begin
  v.extend(100);
  for i in 1..100 loop
    v(i) := dbms_random.string('L', 256);
  end loop;
  insert /*+ append */ into varray_table(id, col1, col2)
  select rownum, v, v
  from dual connect by level <= 100;
  commit;
end;


CREATE /*# or replace debug echo */ TABLE varray_table (
  id number, 
  col1 vcarray,
  col2 vcarray,
  l    clob,
  x    xmltype
)
varray col1 store as basicfile lob SYS_LOB0000077228C00003$$
varray col2 store as securefile lob(nocompress);



