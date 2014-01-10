CREATE OR REPLACE PACKAGE BODY cort_log_pkg 
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
  Description: Logging API
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

  g_logging         BOOLEAN := TRUE; 

  g_action          VARCHAR2(30);
  g_object_type     VARCHAR2(30);
  g_object_owner    VARCHAR2(30);
  g_object_name     VARCHAR2(30);
  
  -- getter
  FUNCTION get_logging 
  RETURN BOOLEAN
  AS
  BEGIN
    RETURN g_logging;
  END get_logging;

  -- setter
  PROCEDURE set_logging(in_status IN BOOLEAN)
  AS
  BEGIN
    IF in_status IS NOT NULL THEN
      g_logging := in_status;
    END IF;  
  END set_logging;

  -- Logs every CORT high level operation
  PROCEDURE log_job(
    in_sid             IN VARCHAR2,
    in_action          IN VARCHAR2,
    in_status          IN VARCHAR2,
    in_job_schema      IN VARCHAR2,
    in_job_name        IN VARCHAR2,
    in_object_type     IN VARCHAR2,
    in_object_owner    IN VARCHAR2,
    in_object_name     IN VARCHAR2,
    in_sql_text        IN CLOB,
    in_partition_pos   IN NUMBER   DEFAULT NULL,
    in_session_params  IN XMLTYPE  DEFAULT NULL,
    in_output          IN CLOB     DEFAULT NULL,
    in_error_code      IN NUMBER   DEFAULT NULL,
    in_error_message   IN VARCHAR2 DEFAULT NULL,
    in_error_stack     IN VARCHAR2 DEFAULT NULL,
    in_error_backtrace IN VARCHAR2 DEFAULT NULL,
    in_call_stack      IN VARCHAR2 DEFAULT NULL,
    in_cort_stack      IN VARCHAR2 DEFAULT NULL
  )
  AS
  PRAGMA autonomous_transaction;
    l_session_rec sys.v_$session%ROWTYPE;
    l_log_rec     cort_job_log%ROWTYPE;
  BEGIN
    IF NOT g_logging THEN
      RETURN;
    END IF;
      
    SELECT *
      INTO l_session_rec
      FROM sys.v_$session
     WHERE SID = SYS_CONTEXT('USERENV','SID');
    
    SELECT cort_log_seq.NEXTVAL
      INTO l_log_rec.job_log_id 
      FROM DUAL;
    
    l_log_rec.job_log_time    := SYSTIMESTAMP;
    l_log_rec.sid             := in_sid;
    l_log_rec.action          := in_action;
    l_log_rec.status          := in_status;
    l_log_rec.job_schema      := in_job_schema;
    l_log_rec.job_name        := in_job_name;
    l_log_rec.object_type     := in_object_type; 
    l_log_rec.object_owner    := in_object_owner;
    l_log_rec.object_name     := in_object_name; 
    l_log_rec.sql_text        := in_sql_text;    
    l_log_rec.partition_pos   := in_partition_pos; 
    l_log_rec.session_params  := in_session_params; 
    l_log_rec.session_id      := l_session_rec.sid;
    l_log_rec.username        := l_session_rec.username;
    l_log_rec.osuser          := l_session_rec.osuser; 
    l_log_rec.machine         := l_session_rec.machine;
    l_log_rec.terminal        := l_session_rec.terminal;
    l_log_rec.program         := l_session_rec.program;
    l_log_rec.session_params  := in_session_params;
    l_log_rec.output          := in_output;
    l_log_rec.error_code      := in_error_code;
    l_log_rec.error_message   := in_error_message;

    l_log_rec.error_stack     := in_error_stack;
    l_log_rec.error_backtrace := in_error_backtrace;
    l_log_rec.cort_stack      := in_cort_stack;
    l_log_rec.call_stack      := in_call_stack;
    
    -- insert new record into log table 
    INSERT INTO cort_job_log
    VALUES l_log_rec; 
    
    COMMIT; 
  END log_job;

  -- Init execution log
  PROCEDURE init_log(
    in_action          IN VARCHAR2,
    in_object_type     IN VARCHAR2,
    in_object_owner    IN VARCHAR2,
    in_object_name     IN VARCHAR2
  )
  AS
  BEGIN
    g_action          := in_action;   
    g_object_type     := in_object_type;  
    g_object_owner    := in_object_owner;   
    g_object_name     := in_object_name;    
  END init_log;
    
  -- Generic logging function
  FUNCTION int_log(
    in_text      IN VARCHAR2,
    in_params    IN CLOB   DEFAULT NULL,
    in_exec_time IN NUMBER DEFAULT NULL
  )
  RETURN NUMBER
  AS
  PRAGMA autonomous_transaction;
    l_log_rec      cort_log%ROWTYPE;
    l_caller_owner VARCHAR2(30);
    l_caller_type  VARCHAR2(30);
  BEGIN
    IF NOT g_logging THEN
      RETURN NULL;
    END IF;

    SELECT cort_log_seq.NEXTVAL
      INTO l_log_rec.log_id 
      FROM DUAL;
    
    owa_util.who_called_me(
      owner      => l_caller_owner,
      name       => l_log_rec.package_name,
      lineno     => l_log_rec.line_number,
      caller_t   => l_caller_type
    );
    
    l_log_rec.log_time        := SYSTIMESTAMP;
    l_log_rec.sid             := SYS_CONTEXT('USERENV','SID');
    l_log_rec.action          := g_action;
    l_log_rec.object_type     := g_object_type; 
    l_log_rec.object_owner    := g_object_owner;
    l_log_rec.object_name     := g_object_name; 
    l_log_rec.text            := in_text;
    l_log_rec.params          := in_params;
    l_log_rec.execution_time  := NULL; 
    
    INSERT INTO cort_log
    VALUES l_log_rec;
    
    COMMIT;
    
    RETURN l_log_rec.log_id;
  END int_log;
  
  -- Warpper for logging function
  FUNCTION log(
    in_text      IN VARCHAR2,
    in_params    IN CLOB   DEFAULT NULL
  )
  RETURN NUMBER
  AS
  BEGIN
    RETURN int_log(
             in_text   => in_text,
             in_params => in_params 
           );
  END log;

  -- Wrapper for logging function
  PROCEDURE log(
    in_text      IN VARCHAR2,
    in_params    IN CLOB   DEFAULT NULL,
    in_exec_time IN NUMBER DEFAULT NULL
  )
  AS
    l_log_id NUMBER;
  BEGIN
    l_log_id := int_log(
                  in_text      => in_text,
                  in_params    => in_params, 
                  in_exec_time => in_exec_time 
                );
  END log;


  PROCEDURE update_exec_time(
    in_log_id IN NUMBER
  )
  AS
  PRAGMA autonomous_transaction;
  BEGIN
    UPDATE cort_log
       SET execution_time = EXTRACT(SECOND FROM SYSTIMESTAMP-log_time)
     WHERE log_id = in_log_id;
    COMMIT; 
  END update_exec_time;
  
  -- Logging procedure execution time
  PROCEDURE log_exec_time(
    in_text       IN VARCHAR2,
    in_start_time IN TIMESTAMP
  )
  AS
    l_exec_time NUMBER;
    l_log_id    NUMBER;
  BEGIN
    l_exec_time := EXTRACT(SECOND FROM SYSTIMESTAMP-in_start_time);
    log(
      in_text      => in_text,
      in_exec_time => l_exec_time 
    );
  END log_exec_time;
  
END cort_log_pkg;
/