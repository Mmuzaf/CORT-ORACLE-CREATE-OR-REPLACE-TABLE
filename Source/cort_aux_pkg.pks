CREATE OR REPLACE PACKAGE cort_aux_pkg 
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
  RETURN CLOB;

  FUNCTION get_last_change_id(
    in_object_owner IN VARCHAR2,
    in_object_type  IN VARCHAR2,
    in_object_name  IN VARCHAR2
  )
  RETURN NUMBER;
  
  PROCEDURE get_change_rollback_ddl(
    in_id             IN NUMBER,
    out_rlbk_stmt_arr OUT NOCOPY arrays.gt_clob_arr
  );

  PROCEDURE register_change(
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2,
    in_sql           IN CLOB,
    in_rollback_name IN VARCHAR2,
    in_frwd_stmt_arr IN arrays.gt_clob_arr,
    in_rlbk_stmt_arr IN arrays.gt_clob_arr
  );
  
  PROCEDURE update_sql(
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2,
    in_sql           IN CLOB
  );
  
  PROCEDURE unregister_last_change(
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2
  );
   
  PROCEDURE cleanup_history(
    in_object_owner  IN VARCHAR2,
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2
  );
  
  PROCEDURE export_stats(
    in_table_rec IN cort_exec_pkg.gt_table_rec
  );

  PROCEDURE import_stats(
    in_table_rec IN cort_exec_pkg.gt_table_rec
  );

  PROCEDURE copy_stats(
    in_source_table_rec IN cort_exec_pkg.gt_table_rec,
    in_target_table_rec IN cort_exec_pkg.gt_table_rec
  );
  
  -- returns retention attributes for segment
  -- Workaround for absence of ALL_SEGMENTS view
  PROCEDURE read_seg_retention(
    in_segment_name   IN  VARCHAR2,
    in_segment_owner  IN  VARCHAR2,
    in_segment_type   IN  VARCHAR2,
    out_retention     OUT VARCHAR2,
    out_minretention  OUT NUMBER
  );
  
  -- enable CORT
  PROCEDURE enable_cort;
  
  -- disable CORT
  PROCEDURE disable_cort;
  
  -- get CORt status (ENABLED/DISABLED)
  FUNCTION get_cort_status
  RETURN VARCHAR2;
  
END cort_aux_pkg;
/