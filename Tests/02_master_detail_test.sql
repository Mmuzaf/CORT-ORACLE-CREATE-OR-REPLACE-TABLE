-- simple heap organized master-detail tables test

drop table detail_table;

drop table master_table cascade constraints;

--version 1
create /*# or replace echo debug */ table master_table(
  id    number,
  value varchar2(30),
  primary key (id)
);

-- sample data
INSERT /*+ append */ INTO master_table(id, value)
SELECT rownum, dbms_random.string('L',20)
  FROM DUAL
CONNECT BY LEVEL <= 100000;

COMMIT;


create /*# or replace echo debug */ table detail_table(
  id        number,
  master_id number references master_table(id),
  process_date date,
  process_user varchar2(30),
  primary key(id)
);

-- sample data
INSERT /*+ append */ INTO detail_table(id, master_id, process_date, process_user)
SELECT rownum, id,  sysdate - mod(rownum,1000) + mod(rownum,100000)/86400, user
  FROM (SELECT * 
          FROM master_table
         CROSS JOIN (SELECT * FROM DUAL
                     CONNECT BY LEVEL <= ROUND(dbms_random.value(5,15)))
       );               

COMMIT;

--version 2 rename constraints
create /*# or replace echo */ table master_table(
  id    number not null,
  value varchar2(30),
  constraint master_table_pk primary key (id) --using index (create unique index master_table_pk on master_table(id))
);

create /*# or replace echo */ table detail_table(
  id        number not null,
  master_id number ,
  process_date date,
  process_user varchar2(30),
  constraint detail_table_pk primary key(id),
  constraint detail2master_fk foreign key(master_id) references master_table(id)
);

exec cort.cort_pkg.set_param_value('debug' ,'true');

--version 3 recreating of master with keeping reference from detail
create /*# or replace echo parallel = 8 debug*/ table master_table (
  id        number not null,
  user_name varchar2(30) not null, --#=user
  value     varchar2(30) default 'Abrakadabra',
  constraint "MASTER_TABLE_PK"primary key (id)
);

--version 4 rename key column
create /*# or replace echo parallel = 8 debug */ table master_table(
  master_id number not null,-- #=id 
  user_name varchar2(30) not null, 
  value     varchar2(30), 
  constraint"MASTER_TABLE_PK"primary key(master_id) using index STORAGE ( NEXT 333   MAXEXTENTS 21474836  BUFFER_POOL default ) 
)
STORAGE ( NEXT 4354  MAXEXTENTS 21474836  BUFFER_POOL KEEP );

--version 4.5 replace PK with UK
create /*# or replace echo parallel = 8 no_debug */ table master_table(
  master_id number not null, 
  user_name varchar2(30) not null, 
  value     varchar2(30), 
  constraint"MASTER_TABLE_PK"   unique(master_id)-- deferrable
)
STORAGE ( NEXT 1048512  MAXEXTENTS 21474836  BUFFER_POOL DEFAULT );

--version 5 alter constraint
create /*# or replace echo */ table DETAIL_TABLE(
  id        number not null,
  master_id number,
  process_date date,
  process_user varchar2(300),
  constraint "DETAIL_TABLE_PK"primary key(id),
  constraint "DETAIL2MASTER_FK"foreign key(master_id) references master_table(master_id) deferrable
);

--version 6 alter constraint with index recreation
create /*# or replace echo parallel = 8 */ table master_table(
  master_id number not null, 
  user_name varchar2(30) not null, 
  value     varchar2(30),
  constraint master_table_pk primary key (master_id) deferrable
);

--version 7 alter constraint with index definition
create /*# or replace echo parallel = 8 */ table master_table(
  master_id number not null, 
  user_name varchar2(30) not null, 
  value     varchar2(30),
  constraint master_table_pk primary key (master_id) using index (create unique index master_table_pk on master_table(master_id)) 
);

--version 8.1 invalid PK change. Will raise CORT error
create /*# or replace echo test */ table master_table(
  master_id number not null, 
  user_name varchar2(30) not null, 
  value     varchar2(30),
  constraint master_table_pk primary key (master_id, user_name) 
);

--version 8.2 PK change with ignoring error and suppressing creation of references
create /*# or replace echo no_bad_refs */ table master_table(
  master_id number not null, 
  user_name varchar2(30) not null, 
  value     varchar2(30),
  constraint master_table_pk primary key (master_id, user_name) 
);

exec cort_pkg.rollback_table('MASTER_TABLE', in_echo => true);

exec cort_pkg.rollback_table('DETAIL_TABLE', in_echo => true);


