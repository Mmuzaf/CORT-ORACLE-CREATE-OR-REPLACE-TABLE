/* version 1 - range partition/hash subpartition test */

drop table part_range;

create /*# or replace echo */ table part_range(
  n1 number,
  n2 number,
  m1 number,
  m2 number
)
partition by range(n1,n2)
  subpartition by hash(m2) 
    subpartition template(
      subpartition sp1,
      subpartition sp2
    )
(
  partition p1_10 values less than (1,10),
  partition p1_20 values less than (1,20),
  partition p1_30 values less than (1,30),
  partition p2_10 values less than (2,10),
  partition p2_20 values less than (2,20),
  partition p2_30 values less than (2,30),
  partition p3_max values less than (3,maxvalue)
);


insert /*+ append */ into part_range
select mod(rownum, 3), mod(rownum, 100), rownum, round(dbms_random.value(1,10000))
  from dual
   connect by level <= 100000;
   
commit;  

-- version 2 - add partition to the end 

create /*# or replace echo  */ table part_range(
  n1 number,
  n2 number,
  m1 number,
  m2 number
)
partition by range(n1,n2)
  subpartition by hash(m2)
    subpartition template(
      subpartition sp1,
      subpartition sp2
    )
(
  partition p1_10 values less than (1,10)
   (subpartition p1_10_sp1 compress,
    subpartition p1_10_sp2,
    subpartition p1_10_sp3,
    subpartition p1_10_sp4
   ),
  partition p1_20 values less than (1,20) (subpartition p1_20_1),
  partition p1_30 values less than (1,30),
  partition p2_10 values less than (2,10),
  partition p2_20 values less than (2,20),
  partition p2_30 values less than (2,30),
  partition p3_30 values less than (3,maxvalue),
  partition max_max values less than (maxvalue,maxvalue) 
);


exec cort_pkg.rollback_table('PART_RANGE', in_echo => true)


drop table part_list;

create /*# or replace echo */ table part_list(
  n1 number,
  n2 number,
  m1 number,
  m2 number
)
partition by list(n1)
(
  partition p_10 values (10),
  partition p_20 values (20),
  partition p_30 values (30),
  partition p_40 values (40),
  partition p_50 values (50),
  partition p_60 values (60),
  partition p_max values (default)
);


insert /*+ append */ into part_list
select mod(rownum, 7), mod(rownum, 100), rownum, round(dbms_random.value(1,10000))
  from dual
   connect by level <= 100000;
   
commit;  

-- version 2 - add partition to the end 

create /*# or replace echo test debug */ table part_list(
  n1 number,
  n2 number,
  m1 number,
  m2 number
)
partition by list(n1)
(
  partition p_10 values (10),
  partition p_20 values (20),
  partition p_50 values (50),
  partition p_40 values (40),
  partition p_30 values (30),
  partition p_60 values (60),
  partition p_max values (default)
);


exec cort_pkg.rollback_table('PART_LIST', in_echo => true)
