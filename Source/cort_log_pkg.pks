CREATE OR REPLACE PACKAGE cort_log_pkg 
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

  -- getter
  FUNCTION get_logging 
  RETURN BOOLEAN;

  -- setter
  PROCEDURE set_logging(in_status IN BOOLEAN);

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
  );
  
  
  -- Init execution log
  PROCEDURE init_log(
    in_action          IN VARCHAR2,
    in_object_type     IN VARCHAR2,
    in_object_owner    IN VARCHAR2,
    in_object_name     IN VARCHAR2
  );  
  
  -- Wrapper for  logging function
  FUNCTION log(
    in_text      IN VARCHAR2,
    in_params    IN CLOB   DEFAULT NULL
  )
  RETURN NUMBER;

  -- Wrapper for logging function
  PROCEDURE log(
    in_text      IN VARCHAR2,
    in_params    IN CLOB   DEFAULT NULL,
    in_exec_time IN NUMBER DEFAULT NULL
  );

  PROCEDURE update_exec_time(
    in_log_id IN NUMBER
  );

  -- Logging procedure execution time
  PROCEDURE log_exec_time(
    in_text       IN VARCHAR2,
    in_start_time IN TIMESTAMP
  );

END cort_log_pkg;
/