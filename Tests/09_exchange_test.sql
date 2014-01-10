drop table virt_cols_test purge;

-- version 1

create /*# or replace */ table virt_cols_test(
  n1 number(10) not null,
  v1 as (mod(n1,3)), -- virtual column
  n2 number,
  n3 number
);

insert /*+ append*/ into virt_cols_test(n1,n2,n3)
select rownum, rownum, rownum
  from dual                  
  connect by level <= 1000;
  
commit;

--version 2: move virtual column. Data should be moved through exchange partition

create /*# or replace echo debug */ table virt_cols_test(
  n1 number(10) not null,
  n2 number,
  v1 as (mod(n1,3)),  -- virtual column
  n3 number,
  n4 number
);


exec cort.cort_pkg.set_param_bool_value('echo', true);

exec cort.cort_pkg.set_param_bool_value('debug', true);

exec cort.cort_pkg.rollback_table('VIRT_COLS_TEST');

