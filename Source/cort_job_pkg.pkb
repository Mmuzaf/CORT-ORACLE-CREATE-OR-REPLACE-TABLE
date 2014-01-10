CREATE OR REPLACE PACKAGE BODY cort_job_pkg 
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
  Description: job execution API
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

  gc_cort_job_name    CONSTANT VARCHAR2(30) := '#cort#job#';

  -- Run infinit loop until job is done
  FUNCTION wait_for_job_end(
    in_sid IN NUMBER
  ) 
  RETURN cort_jobs%ROWTYPE
  AS
    l_rec        cort_jobs%ROWTYPE;
    l_empty_rec  cort_jobs%ROWTYPE;
    l_cnt        PLS_INTEGER;
  BEGIN
    -- infinity loop
    LOOP
      BEGIN
        SELECT *
          INTO l_rec
          FROM cort_jobs
         WHERE sid = in_sid;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          EXIT;
      END;   
      IF l_rec.status <> 'RUNNING' THEN
        RETURN l_rec;
      END IF;
      -- check that running job exists
      SELECT COUNT(*)
        INTO l_cnt
        FROM all_scheduler_jobs
       WHERE owner = l_rec.job_schema
         AND job_name = gc_cort_job_name||in_sid;
         
      -- check that record is picked up by job process 
      IF l_cnt > 0 AND l_rec.job_sid IS NOT NULL THEN
        -- check that jobs session exists
        SELECT COUNT(*)
          INTO l_cnt 
          FROM v$session
         WHERE SID = l_rec.job_sid;  
      END IF;
      
      IF l_cnt = 0 THEN
        EXIT;
      END IF;   
    END LOOP;
    RETURN l_empty_rec;
  END wait_for_job_end;

  -- add record for given job
  PROCEDURE register_job(
    in_sid           IN NUMBER,
    in_action        IN VARCHAR2,
    in_job_schema    IN VARCHAR2,
    in_job_name      IN VARCHAR2,
    in_object_name   IN VARCHAR2,
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_sql           IN CLOB,
    in_partition_pos IN NUMBER
  )
  AS
  PRAGMA autonomous_transaction;
    l_cnt        PLS_INTEGER;  
    l_rec        cort_jobs%ROWTYPE;
    l_params     cort_params_pkg.gt_params_rec;
    l_params_xml XMLType;
  BEGIN
    -- delete all record for current session 
    DELETE FROM cort_jobs
     WHERE sid = in_sid
       AND status IN ('SUCCESS','FAILED');
    COMMIT;   
       
    l_params := cort_pkg.get_params;
    cort_xml_pkg.write_to_xml(l_params, l_params_xml);
    -- Start loop
    LOOP
      l_cnt := 0;  

      -- Check that there is no RUNNING job for current session   
      BEGIN
        SELECT *
          INTO l_rec
          FROM cort_jobs
         WHERE status <> 'RUNNING'
           AND sid = in_sid;
        l_cnt := 1;  
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_cnt := 0;
      END;   
      
      IF l_cnt = 0 THEN
        -- check that given object is not changing by another session  
        BEGIN
          SELECT *
            INTO l_rec
            FROM cort_jobs
           WHERE object_name = in_object_name
             AND object_owner = in_object_owner
             AND status = 'RUNNING'
             FOR UPDATE WAIT 1;
          l_cnt := 1;  
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            l_cnt := 0;
        END;
      END IF;
      
      IF l_cnt = 1 THEN
        -- Check that found sessions are stil alive 
        SELECT COUNT(*) 
          INTO l_cnt
          FROM v$session
         WHERE SID IN (l_rec.sid, l_rec.job_sid);
         
        IF l_cnt > 0 AND l_rec.sid <> in_sid THEN
          -- sessions are alive
          RAISE_APPLICATION_ERROR(-20000, in_object_type||' "'||in_object_owner||'"."'||in_object_name||'" is changing by another process');
        ELSE
          -- delete records for dead sessions
          DELETE FROM cort_jobs
           WHERE sid = in_sid;
          COMMIT;
          l_cnt := 0;
        END IF;  
      END IF;
             
      IF l_cnt = 0 THEN
        BEGIN
          -- Try to register new job
          INSERT INTO cort_jobs
            (sid,action,status,job_schema,job_name,object_type,object_owner,object_name,sql_text,partition_pos,session_params)
          VALUES
            (in_sid,in_action,'RUNNING',in_job_schema,in_job_name,in_object_type,in_object_owner,in_object_name,in_sql,in_partition_pos,l_params_xml);
        EXCEPTION
          WHEN DUP_VAL_ON_INDEX THEN
            l_cnt := 1;
        END;
      END IF;

      EXIT WHEN l_cnt = 0;
      
    END LOOP;
    
    cort_log_pkg.log_job(
      in_sid             => in_sid,
      in_action          => in_action,
      in_status          => 'REGISTERING',
      in_job_schema      => in_job_schema,
      in_job_name        => in_job_name,
      in_object_type     => in_object_type,
      in_object_owner    => in_object_owner,
      in_object_name     => in_object_name,
      in_sql_text        => in_sql,
      in_partition_pos   => in_partition_pos,
      in_session_params  => l_params_xml
    );    
    
    
    COMMIT;
  END register_job; 
  
  -- Public 
  
  -- Return job record
  FUNCTION get_job(
    in_sid IN NUMBER
  ) 
  RETURN cort_jobs%ROWTYPE
  AS
  PRAGMA autonomous_transaction;
    l_rec cort_jobs%ROWTYPE;
  BEGIN
    BEGIN
      SELECT *
        INTO l_rec
        FROM cort_jobs
       WHERE sid = in_sid
         AND status = 'RUNNING'
         AND job_sid IS NULL
         FOR UPDATE;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;  
    
    UPDATE cort_jobs
       SET job_sid = SYS_CONTEXT('SID','USERENV') 
     WHERE sid = in_sid
       AND status = 'RUNNING'
       AND job_sid IS NULL;

    COMMIT;
    
    cort_log_pkg.log_job(
      in_sid             => in_sid,
      in_action          => l_rec.action,
      in_status          => 'EXECUTING',
      in_job_schema      => l_rec.job_schema,
      in_job_name        => l_rec.job_name,
      in_object_type     => l_rec.object_type,
      in_object_owner    => l_rec.object_owner,
      in_object_name     => l_rec.object_name,
      in_sql_text        => l_rec.sql_text,
      in_partition_pos   => l_rec.partition_pos,
      in_session_params  => l_rec.session_params
    );    
     
    RETURN l_rec;
  END get_job;
  
  -- Finish job
  PROCEDURE success_job(
    in_sid IN NUMBER
  )
  AS
  PRAGMA autonomous_transaction;
    l_lines     dbms_output.chararr;
    l_num_lines INTEGER := 2147483647;
    l_output    CLOB;
  BEGIN
    dbms_output.get_lines(l_lines, l_num_lines);
    cort_exec_pkg.lines_to_clob(l_lines, l_output);          
    UPDATE cort_jobs
       SET status = 'SUCCESS',
           output = l_output
     WHERE sid = in_sid
       AND status = 'RUNNING'
    ;
    COMMIT;
  END success_job; 
  
  -- Finish job with error
  PROCEDURE fail_job(
    in_sid             IN NUMBER,
    in_error_code      IN NUMBER,
    in_error_message   IN VARCHAR2,
    in_error_stack     IN VARCHAR2,
    in_error_backtrace IN VARCHAR2,
    in_call_stack      IN VARCHAR2,
    in_cort_stack      IN VARCHAR2
  )
  AS
  PRAGMA autonomous_transaction;
    l_lines      dbms_output.chararr;
    l_num_lines  INTEGER := 2147483647;
    l_output     CLOB;
    l_rec        cort_jobs%ROWTYPE;
    l_params     cort_params_pkg.gt_params_rec;
    l_params_xml XMLTYPE;
  BEGIN
    dbms_output.get_lines(l_lines, l_num_lines);
    cort_exec_pkg.lines_to_clob(l_lines, l_output);          

    BEGIN
      SELECT * 
        INTO l_rec
        FROM cort_jobs
       WHERE sid = in_sid
         AND status = 'RUNNING'
      ;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        NULL;
    END;  

    l_params := cort_pkg.get_params;
    cort_xml_pkg.write_to_xml(l_params, l_params_xml);
 
    cort_log_pkg.log_job(
      in_sid             => in_sid,
      in_action          => l_rec.action,
      in_status          => 'FAILED',
      in_job_schema      => l_rec.job_schema,
      in_job_name        => l_rec.job_name,
      in_object_type     => l_rec.object_type,
      in_object_owner    => l_rec.object_owner,
      in_object_name     => l_rec.object_name,
      in_sql_text        => l_rec.sql_text,
      in_partition_pos   => l_rec.partition_pos,
      in_session_params  => l_params_xml,
      in_output          => l_output,
      in_error_code      => in_error_code,
      in_error_message   => in_error_message,
      in_error_stack     => in_error_stack,
      in_error_backtrace => in_error_backtrace,
      in_call_stack      => in_call_stack,
      in_cort_stack      => in_cort_stack
    );    

    UPDATE cort_jobs
       SET status          = 'FAILED',
           output          = l_output,
           error_code      = in_error_code,
           error_message   = in_error_message,
           error_stack     = in_error_stack,
           error_backtrace = in_error_backtrace,
           call_stack      = in_call_stack,
           cort_stack      = in_cort_stack
     WHERE sid = in_sid
       AND status = 'RUNNING'
    ;
    COMMIT;
    
  END fail_job; 

  -- Start job
  PROCEDURE start_job(
    in_action        IN VARCHAR2,
    in_object_name   IN VARCHAR2,
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_sql           IN CLOB,
    in_partition_pos IN NUMBER DEFAULT NULL
  )
  AS
  PRAGMA autonomous_transaction;
    l_rec                 cort_jobs%ROWTYPE;
    l_lines               dbms_output.chararr;
    l_sid                 NUMBER;
    l_job_name            VARCHAR2(30);
    l_job_full_name       VARCHAR2(65);
    l_job_action          VARCHAR2(200);
    e_job_already_exists  EXCEPTION; 
    PRAGMA                EXCEPTION_INIT(e_job_already_exists, -27477); 
  BEGIN
    l_sid := SYS_CONTEXT('USERENV','SID');
    l_job_name := gc_cort_job_name||l_sid;
    l_job_full_name := '"'||user||'"."'||l_job_name||'"';
    l_job_action := '"'||SYS_CONTEXT('USERENV','CURRENT_USER')||'".CORT_PKG.EXECUTE_ACTION';
    
    BEGIN
      dbms_scheduler.create_job(
        job_name            => l_job_full_name,
        job_type            => 'STORED_PROCEDURE',
        job_action          => l_job_action,
        number_of_arguments => 1,
        auto_drop           => TRUE,
        enabled             => FALSE
      );
    EXCEPTION
      WHEN e_job_already_exists THEN
        NULL;
    END; 
    dbms_scheduler.set_job_argument_value(
      job_name          => l_job_full_name,
      argument_position => 1,
      argument_value    => l_sid
    );
    register_job(
      in_sid           => l_sid,
      in_action        => in_action,
      in_job_schema    => user,
      in_job_name      => l_job_name,
      in_object_name   => in_object_name,
      in_object_owner  => in_object_owner,
      in_object_type   => in_object_type,
      in_sql           => in_sql,
      in_partition_pos => in_partition_pos
    );
    dbms_scheduler.enable(
      name => l_job_full_name
    );
    COMMIT;

    l_rec := wait_for_job_end(
      in_sid => l_sid
    );
    
    IF (l_rec.status = 'RUNNING') OR (l_rec.status IS NULL) THEN
      fail_job(
        in_sid             => l_sid,
        in_error_code      => sqlcode,
        in_error_message   => sqlerrm,
        in_error_stack     => dbms_utility.format_error_stack,
        in_error_backtrace => dbms_utility.format_error_backtrace,
        in_call_stack      => dbms_utility.format_call_stack,
        in_cort_stack      => NULL
      );
    END IF;
    dbms_output.enable(buffer_size => 1000000);
    cort_exec_pkg.clob_to_lines(l_rec.output, l_lines);     
    FOR i IN 1..l_lines.COUNT LOOP
      dbms_output.put_line(l_lines(i));
    END LOOP;
    
    IF l_rec.status = 'FAILED' THEN
      IF l_rec.error_code = -20992 
      THEN
        RAISE_APPLICATION_ERROR(
          l_rec.error_code,
          REPLACE(l_rec.error_message, 'ORA-20992: ', NULL) 
        );
      ELSE
      RAISE_APPLICATION_ERROR(
        -20000,
        'CORT internal error'||CHR(10)||
        l_rec.error_stack||
        l_rec.error_backtrace
      );
      END IF;
    END IF;
    COMMIT;         
  END start_job;

END cort_job_pkg;
/