CREATE OR REPLACE PACKAGE BODY cort_aux_pkg 
AS
  
/*
CORT - Oracle server-side tool allowing to change tables similar to create or replace command

Copyright (C) 2013-2014  Softcraft Ltd - Rustam Kafarov

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/*
  Description: Auxilary functionality executed with CORT user privileges
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

  FUNCTION get_last_change_sql(
    in_object_owner IN VARCHAR2,
    in_object_type  IN VARCHAR2,
    in_object_name  IN VARCHAR2
  )  
  RETURN CLOB
  AS
    l_sql CLOB;
  BEGIN
    BEGIN
      SELECT sql_text
        INTO l_sql    
        FROM cort_objects
       WHERE object_owner = in_object_owner 
         AND object_name = in_object_name 
         AND object_type = in_object_type
         AND end_time = cort_exec_pkg.gc_max_end_time;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_sql := NULL;
    END;
    RETURN l_sql;
  END get_last_change_sql;

  FUNCTION get_last_change_id(
    in_object_owner IN VARCHAR2,
    in_object_type  IN VARCHAR2,
    in_object_name  IN VARCHAR2
  )  
  RETURN NUMBER
  AS
    l_id NUMBER(15);
  BEGIN
    BEGIN
      SELECT id
        INTO l_id    
        FROM cort_objects
       WHERE object_owner = in_object_owner 
         AND object_name = in_object_name 
         AND object_type = in_object_type
         AND end_time = cort_exec_pkg.gc_max_end_time
         AND del_flag IS NULL;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_id := NULL;
    END;
    RETURN l_id;
  END get_last_change_id;
  
  PROCEDURE reverse_array(
    io_array IN OUT NOCOPY arrays.gt_clob_arr
  )
  AS
    l_indx_frwd PLS_INTEGER;
    l_indx_bkwd PLS_INTEGER;
    l_cnt       PLS_INTEGER;
    l_swap      CLOB;
  BEGIN
    l_cnt := 1;
    l_indx_frwd := io_array.FIRST;
    l_indx_bkwd := io_array.LAST;
    WHILE l_cnt <= TRUNC(io_array.COUNT/2) AND 
          l_indx_frwd IS NOT NULL AND 
          l_indx_bkwd IS NOT NULL 
    LOOP
      l_swap := io_array(l_indx_frwd);
      io_array(l_indx_frwd) := io_array(l_indx_bkwd);
      io_array(l_indx_bkwd) := l_swap; 
      l_indx_frwd := io_array.NEXT(l_indx_frwd);
      l_indx_bkwd := io_array.PRIOR(l_indx_bkwd);
      l_cnt := l_cnt + 1;
    END LOOP;
  END reverse_array;

  PROCEDURE get_change_rollback_ddl(
    in_id             IN NUMBER,
    out_rlbk_stmt_arr OUT NOCOPY arrays.gt_clob_arr
  )
  AS
    l_rollback_ddl_xml  XMLTYPE;
  BEGIN
    SELECT rollback_ddl
      INTO l_rollback_ddl_xml
      FROM cort_objects
     WHERE id = in_id;

    cort_xml_pkg.read_from_xml(  
      in_value => l_rollback_ddl_xml,
      out_arr  => out_rlbk_stmt_arr
    );
  END get_change_rollback_ddl;

  PROCEDURE register_change(
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2,
    in_sql           IN CLOB,
    in_rollback_name IN VARCHAR2,
    in_frwd_stmt_arr IN arrays.gt_clob_arr,
    in_rlbk_stmt_arr IN arrays.gt_clob_arr
  )
  AS
    l_id            NUMBER(15);
    l_prev_id       NUMBER(15);
    l_indx_arr      arrays.gt_num_arr;
    l_rec           cort_objects%ROWTYPE;
    l_rlbk_stmt_arr arrays.gt_clob_arr;
    l_systime       TIMESTAMP := SYSTIMESTAMP;
    l_application   cort_objects.application%TYPE; 
    l_version       cort_objects.version%TYPE;
  BEGIN
    UPDATE cort_objects
       SET end_time = l_systime
     WHERE object_owner = in_object_owner 
       AND object_name = in_object_name 
       AND object_type = in_object_type
       AND end_time = cort_exec_pkg.gc_max_end_time
    RETURNING id, application, version 
         INTO l_prev_id, l_application, l_version;
    
    SELECT cort_obj_seq.nextval
      INTO l_rec.id 
      FROM dual;
      
    l_rec.object_owner := in_object_owner; 
    l_rec.object_name := in_object_name;
    l_rec.object_type := in_object_type;
    l_rec.start_time := l_systime;
    l_rec.end_time := cort_exec_pkg.gc_max_end_time;
    l_rec.sql_text := in_sql;
    l_rec.rollback_name := in_rollback_name;
    l_rec.prev_id := l_prev_id;
    l_rec.del_flag := NULL;
    l_rec.application := cort_exec_pkg.g_params.application;
    l_rec.version := cort_exec_pkg.g_params.version;
    
    cort_xml_pkg.write_to_xml(  
      in_value => in_frwd_stmt_arr,
      out_xml  => l_rec.forward_ddl
    );
    
    l_rlbk_stmt_arr := in_rlbk_stmt_arr;
    
    reverse_array(l_rlbk_stmt_arr);
    
    cort_xml_pkg.write_to_xml(  
      in_value => l_rlbk_stmt_arr,
      out_xml  => l_rec.rollback_ddl
    );

    INSERT INTO cort_objects 
    VALUES l_rec;

  END register_change;
  
  PROCEDURE update_sql(
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2,
    in_sql           IN CLOB
  )
  AS
  BEGIN
    UPDATE cort_objects
       SET sql_text = in_sql
     WHERE object_owner = in_object_owner 
       AND object_name = in_object_name 
       AND object_type = in_object_type
       AND end_time = cort_exec_pkg.gc_max_end_time;
  END update_sql;
  
    
  PROCEDURE unregister_last_change(
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2
  )
  AS
    l_prev_id NUMBER(15);
  BEGIN
    DELETE 
      FROM cort_objects
     WHERE object_owner = in_object_owner 
       AND object_name = in_object_name 
       AND object_type = in_object_type
       AND end_time = cort_exec_pkg.gc_max_end_time
    RETURNING prev_id INTO l_prev_id; 
    
    UPDATE cort_objects
       SET end_time = cort_exec_pkg.gc_max_end_time
     WHERE id = l_prev_id;
    
  END unregister_last_change;

  PROCEDURE cleanup_history(
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2
  )
  AS
  BEGIN
    DELETE 
      FROM cort_objects
     WHERE object_owner = in_object_owner 
       AND object_name = in_object_name 
       AND object_type = in_object_type;
  END cleanup_history;     
  

  PROCEDURE export_stats(
    in_table_rec IN cort_exec_pkg.gt_table_rec
  )
  AS
  BEGIN
    dbms_stats.export_table_stats(
      ownname => '"'||in_table_rec.owner||'"',
      tabname => '"'||in_table_rec.rename_rec.current_name||'"',
      stattab => cort_exec_pkg.gc_stat_table_name,
      statown => SYS_CONTEXT('USERENV','CURRENT_USER')
    );
  END export_stats;

  PROCEDURE import_stats(
    in_table_rec IN cort_exec_pkg.gt_table_rec
  )
  AS
  BEGIN
    dbms_stats.import_table_stats(
      ownname => '"'||in_table_rec.owner||'"',
      tabname => '"'||in_table_rec.rename_rec.current_name||'"',
      stattab => cort_exec_pkg.gc_stat_table_name,
      statown => SYS_CONTEXT('USERENV','CURRENT_USER')
    );
  END import_stats;
  
  PROCEDURE copy_stats(
    in_source_table_rec IN cort_exec_pkg.gt_table_rec,
    in_target_table_rec IN cort_exec_pkg.gt_table_rec
  )
  AS
  BEGIN
    export_stats(in_source_table_rec);
    UPDATE cort_stat
       SET C1 = in_target_table_rec.rename_rec.current_name
     WHERE C1 = in_source_table_rec.rename_rec.current_name;
    COMMIT;  
    import_stats(in_target_table_rec);
  END copy_stats;

  -- returns retention attributes for segment
  -- Workaround for absence of ALL_SEGMENTS view 
  PROCEDURE read_seg_retention(
    in_segment_name   IN VARCHAR2,
    in_segment_owner  IN VARCHAR2,
    in_segment_type   IN VARCHAR2,
    out_retention     OUT VARCHAR2,
    out_minretention  OUT NUMBER
  )
  AS
  BEGIN
    BEGIN
      SELECT NVL(retention,'NONE'), NULLIF(minretention,0) 
        INTO out_retention, out_minretention   
        FROM dba_segments
       WHERE segment_type = in_segment_type
         AND segment_name = in_segment_name
         AND owner = in_segment_owner;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN 
        out_retention := 'NONE'; 
        out_minretention := 0;
    END;     
  END read_seg_retention;

  PROCEDURE enable_cort
  AS
  BEGIN
    cort_exec_pkg.execute_immediate('ALTER TRIGGER CORT_CREATE_TRG ENAABLE', NULL);
  END enable_cort;
  
  PROCEDURE disable_cort
  AS
  BEGIN
    cort_exec_pkg.execute_immediate('ALTER TRIGGER CORT_CREATE_TRG DISABLE', NULL);
  END disable_cort;
  
  FUNCTION get_cort_status
  RETURN VARCHAR2
  AS
    l_status VARCHAR2(30);
  BEGIN
    BEGIN
      SELECT status
        INTO l_status
        FROM user_triggers
       WHERE trigger_name = 'CORT_CREATE_TRG';    
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_status := NULL;
    END;
    RETURN l_status;
  END get_cort_status;

END cort_aux_pkg;
/