declare
  l_sql varchar2(4000);
begin
  for x in (select * 
              from all_tables 
             where table_name like 'rlbk#%' or
                   table_name like '~tmp#%'
           ) loop
    l_sql := 'drop table "'||x.owner||'"."'||x.table_name||'" cascade constraints purge';
    dbms_output.put_line(l_sql);
    execute immediate l_sql;
  end loop;
  if user = 'CORT' then 
    l_sql := 'truncate table cort_log';         
    dbms_output.put_line(l_sql);
    execute immediate l_sql;
    l_sql := 'truncate table cort_job_log';         
    dbms_output.put_line(l_sql);
    execute immediate l_sql;
    l_sql := 'truncate table cort_jobs';         
    dbms_output.put_line(l_sql);
    execute immediate l_sql;
    l_sql := 'truncate table cort_objects';         
    dbms_output.put_line(l_sql);
    execute immediate l_sql;
  end if;
end;
/
