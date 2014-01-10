-- version 1

create /*# or replace echo debug */ table test_types(
  id number       not null,
  r  raw(4)       not null,
  n  number(20),
  s  varchar2(20),
  t  timestamp(6)
)
;

insert /*+ append */ into test_types
select rownum, utl_raw.cast_from_number(rownum), rownum, dbms_random.string('L',10), systimestamp
  from dual
   connect by level <= 1000;
   
commit;  


-- version 2 - increasing length of raw, varchar2 - goes thru alter

create /*# or replace echo debug */ table test_types(
  id number not null,
  r  raw(40) not null,
  n  number(20),
  s  varchar2(40),
  t  timestamp(6)
)
;


-- version 3 - increasing length of number, timestamp - goes thru recreate

create /*# or replace echo */ table test_types(
  id number not null,
  r  raw(40) not null,
  n  number(22,2),
  s  varchar2(40),
  t  timestamp(9)
)
;

-- version 4 - changing varchar2 to clob

create /*# or replace echo */ table test_types(
  id number not null,
  r  raw(40) not null,
  n  number(22,2),
  s  clob,
  t  timestamp(9)
)
;

-- version 5 - changing clob to XMLType

create /*# or replace echo  */ table test_types(
  id number not null,
  r  raw(40) not null,
  a number,
  n  number(22,2),--#==-123
  s  XMLType,  --#=XMLType('<xml>'||s||'</xml>') 
  t  timestamp(9)--#=systimestamp
)
;

create or replace type test_typ as object(
  attr1 varchar2(200),
  attr2 varchar2(200)
);

-- version 6 - changing XMLType to user_defined type

create /*# or replace echo */ table test_types(
  id number not null,
  r  raw(40) not null,
  n  number(22,2),
  s  test_typ, --#=test_typ(a.s.GetStringVal(),extract(a.s,'XML/text()')) 
  t  timestamp(9)
)
;

exec cort_pkg.set_param_value('debug', 'false')

exec cort_pkg.rollback_table('TEST_TYPES', in_echo => true);