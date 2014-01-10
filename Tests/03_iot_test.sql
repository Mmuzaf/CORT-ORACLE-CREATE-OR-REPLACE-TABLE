-- IOT organized master-detail tables test

--version 1
create /*# or replace echo debug */ table iot_master_table(
  id    number,
  value varchar2(30),
  primary key (id)
);

-- sample data
INSERT /*+ append */ INTO iot_master_table(id, value)
SELECT rownum, dbms_random.string('L',20)
  FROM DUAL
CONNECT BY LEVEL <= 100000;

COMMIT;


create /*# or replace echo debug */ table iot_detail_table(
  id        number,
  master_id number references iot_master_table(id),
  process_date date,
  process_user varchar2(30),
  primary key(id)
);

-- sample data
INSERT /*+ append */ INTO iot_detail_table(id, master_id, process_date, process_user)
SELECT rownum, id,  sysdate - mod(rownum,1000) + mod(rownum,100000)/86400, user
  FROM (SELECT * 
          FROM iot_master_table
         CROSS JOIN (SELECT * FROM DUAL
                     CONNECT BY LEVEL <= ROUND(dbms_random.value(5,15)))
       );               

COMMIT;

--version 2 rename constraints; recreate table as table IOT
create /*# or replace echo  debug */ table iot_master_table(
  id    number not null,
  value varchar2(30),
  constraint iot_master_table_pk primary key (id)
)
organization index
STORAGE ( NEXT 13453453  MAXEXTENTS 21474836  BUFFER_POOL DEFAULT );

create /*# or replace echo test */ table iot_detail_table(
  id        number not null,
  master_id number ,
  process_date date,
  process_user varchar2(30),
  constraint iot_detail_table_pk primary key(id),
  constraint iot_detail2iot_master_fk foreign key(master_id) references iot_master_table(id)
)
organization index;


-- version 3

create /*# or replace echo debug */ table iot_detail_table(
  id        number not null,
  master_id number ,
  process_date date default sysdate not null,
  process_user varchar2(30) default user not null,
  constraint iot_detail_table_pk primary key(id),
  constraint iot_detail2iot_master_fk foreign key(master_id) references iot_master_table(id)
)
organization index;


-- version 4

create /*# or replace echo no_debug no_rollback test */ table iot_detail_table(
  id        number not null,
  master_id number ,
  process_date date default sysdate not null,
  process_user varchar2(30) default user not null,
  big_data clob,
  constraint iot_detail_table_pk primary key(id),
  constraint iot_detail2iot_master_fk foreign key(master_id) references iot_master_table(id)
)
organization index
overflow --including()
--nomapping
mapping table

;

exec cort_pkg.rollback_table('IOT_MASTER_TABLE', in_echo => true, in_test => true);

exec cort_pkg.rollback_table('IOT_DETAIL_TABLE', in_echo => true);



