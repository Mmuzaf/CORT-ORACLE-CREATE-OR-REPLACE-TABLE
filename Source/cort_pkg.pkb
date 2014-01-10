CREATE OR REPLACE PACKAGE BODY cort_pkg
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
  Description: API for end-user - wrappers around main procedures/functions.  
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

  g_session_params_rec   gt_params_rec := cort_params_pkg.get_default_rec;
  
  /* Private */
  
  FUNCTION update_params_rec(in_params IN gt_params)
  RETURN gt_params_rec
  AS
    l_params_rec   gt_params_rec;
  BEGIN 
    l_params_rec := g_session_params_rec;        
    IF in_params IS NOT NULL THEN 
      FOR i IN 1..in_params.COUNT LOOP 
        cort_params_pkg.set_param_value(l_params_rec, in_params(i).name, in_params(i).value);
      END LOOP;  
    END IF;
    RETURN l_params_rec; 
  END update_params_rec;
  
  /* Public */

  FUNCTION param(
    in_name  IN VARCHAR2,
    in_value IN VARCHAR2
  )
  RETURN gt_param_rec
  AS
    l_result  gt_param_rec;
  BEGIN
    l_result.name := in_name;
    l_result.type := 'VARCHAR2';
    l_result.value := in_value;
    RETURN l_result;
  END param;
  
  FUNCTION param(
    in_name  IN VARCHAR2,
    in_value IN NUMBER
  )
  RETURN gt_param_rec
  AS
    l_result  gt_param_rec;
  BEGIN
    l_result.name := in_name;
    l_result.type := 'NUMBER';
    l_result.value := TO_CHAR(in_value);
    RETURN l_result;
  END param;
  
  FUNCTION param(
    in_name  IN VARCHAR2,
    in_value IN BOOLEAN
  )
  RETURN gt_param_rec
  AS
    l_result  gt_param_rec;
  BEGIN
    l_result.name := in_name;
    l_result.type := 'BOOLEAN';
    l_result.value := cort_params_pkg.bool_to_str(in_value);
    RETURN l_result;
  END param;

  -- getters for session params
  FUNCTION get_params
  RETURN gt_params_rec
  AS
  BEGIN
    RETURN g_session_params_rec;
  END get_params;
  
  
  FUNCTION get_param_value(
    in_param_name   IN VARCHAR2
  )
  RETURN VARCHAR2
  AS
  BEGIN
    RETURN cort_params_pkg.get_param_value(g_session_params_rec, in_param_name);
  END get_param_value;
  
  FUNCTION get_param_bool_value(
    in_param_name   IN VARCHAR2
  )
  RETURN BOOLEAN
  AS
  BEGIN
    RETURN cort_params_pkg.str_to_bool(cort_params_pkg.get_param_value(g_session_params_rec, in_param_name));
  END get_param_bool_value;

  -- setters for session params
  PROCEDURE set_param_value(
    in_param_name   IN VARCHAR2,
    in_param_value  IN NUMBER
  )
  AS
  BEGIN
    cort_params_pkg.set_param_value(g_session_params_rec, in_param_name, in_param_value);
  END set_param_value;

  PROCEDURE set_param_value(
    in_param_name   IN VARCHAR2,
    in_param_value  IN VARCHAR2
  )
  AS
  BEGIN
    cort_params_pkg.set_param_value(g_session_params_rec, in_param_name, in_param_value);
  END set_param_value;
  
  PROCEDURE set_param_value(
    in_param_name   IN VARCHAR2,
    in_param_value  IN BOOLEAN
  )
  AS
  BEGIN
    cort_params_pkg.set_param_value(g_session_params_rec, in_param_name, cort_params_pkg.bool_to_str(in_param_value));
  END set_param_value;

  -- Procedure is called from job
  PROCEDURE execute_action(
    in_sid IN NUMBER
  )
  AS
    l_rec        cort_jobs%ROWTYPE;
    l_start_time TIMESTAMP := SYSTIMESTAMP;
    l_params     cort_params_pkg.gt_params_rec;
  BEGIN
    dbms_output.enable(buffer_size => 1000000);

    l_rec := cort_job_pkg.get_job(
               in_sid => in_sid
             );
    
    cort_log_pkg.init_log(
      in_action       => l_rec.action,
      in_object_type  => l_rec.object_type,
      in_object_owner => l_rec.object_owner,
      in_object_name  => l_rec.object_name
    );
      
    cort_xml_pkg.read_from_xml(l_rec.session_params, l_params); 
    
    BEGIN
      cort_exec_pkg.set_context(l_rec.action||'_'||l_rec.object_type,l_rec.object_name);

      CASE l_rec.action||'_'||l_rec.object_type
      WHEN 'CREATE_OR_REPLACE_TABLE' THEN
        cort_exec_pkg.create_or_replace_table(
          in_table_name     => l_rec.object_name,
          in_owner          => l_rec.object_owner,
          in_sql            => l_rec.sql_text,       
          in_partition_pos  => l_rec.partition_pos, 
          in_params_rec     => l_params
        );
      WHEN 'DROP_TABLE' THEN
        NULL;    
      END CASE;

      cort_exec_pkg.set_context(l_rec.action||'_'||l_rec.object_type,NULL);

      cort_job_pkg.success_job(
        in_sid => in_sid
      );
    EXCEPTION
      WHEN OTHERS THEN
        cort_exec_pkg.set_context(l_rec.action||'_'||l_rec.object_type,NULL);
        cort_job_pkg.fail_job(
          in_sid             => in_sid,
          in_error_code      => sqlcode,
          in_error_message   => sqlerrm,
          in_error_stack     => dbms_utility.format_error_stack,
          in_error_backtrace => dbms_utility.format_error_backtrace,
          in_call_stack      => dbms_utility.format_call_stack,          
          in_cort_stack      => cort_exec_pkg.get_error_stack
        );
        cort_log_pkg.log_exec_time(
          in_text       => 'FINISH JOB WITH ERROR',
          in_start_time => l_start_time 
        );
        RAISE;
    END;
    
    cort_log_pkg.log_exec_time(
      in_text       => 'FINISH JOB',
      in_start_time => l_start_time 
    );
  END execute_action;

  -- Rollback the latest change for given table
  PROCEDURE rollback_table(
    in_table_name  IN VARCHAR2,
    in_owner_name  IN VARCHAR2,
    in_params      IN gt_params 
  )
  AS
  BEGIN
    dbms_output.enable(buffer_size => 1000000);

    cort_log_pkg.init_log(
      in_action       => 'ROLLBACK',
      in_object_type  => 'TABLE',
      in_object_owner => in_owner_name,
      in_object_name  => in_table_name
    );
  
    cort_exec_pkg.rollback_change(
      in_object_type    => 'TABLE',
      in_object_name    => in_table_name,
      in_object_owner   => in_owner_name,
      in_params_rec     => update_params_rec(in_params)
    );
  END rollback_table;

  -- Rollback the latest change for given table (overloaded)
  PROCEDURE rollback_table(
    in_table_name  IN VARCHAR2,
    in_owner_name  IN VARCHAR2 DEFAULT USER,
    in_echo        IN BOOLEAN  DEFAULT NULL,  -- NULL - take from session param 
    in_test        IN BOOLEAN  DEFAULT NULL   -- NULL - take from session param
  )
  AS   
    l_params   gt_params := gt_params();
  BEGIN
    IF in_echo IS NOT NULL THEN
      l_params.EXTEND;
      l_params(l_params.LAST) := param('echo', in_echo);
    END IF;
    IF in_test IS NOT NULL THEN
      l_params.EXTEND;
      l_params(l_params.LAST) := param('test', in_test);
    END IF;
    rollback_table(
      in_table_name => in_table_name,
      in_owner_name => in_owner_name,
      in_params     => l_params 
    );
  END rollback_table;
  
  PROCEDURE enable_cort
  AS
  BEGIN
    cort_aux_pkg.enable_cort;
  END enable_cort;
  
  PROCEDURE disable_cort
  AS
  BEGIN
    cort_aux_pkg.disable_cort;
  END disable_cort;
  
  FUNCTION get_cort_status
  RETURN VARCHAR2
  AS
  BEGIN
    RETURN cort_aux_pkg.get_cort_status;
  END get_cort_status;

END cort_pkg;
/