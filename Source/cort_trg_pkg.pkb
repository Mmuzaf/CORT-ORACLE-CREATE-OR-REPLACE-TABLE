CREATE OR REPLACE PACKAGE BODY cort_trg_pkg
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
  Description: functionality called from create trigger     
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

  -- parses main CORT hint
  FUNCTION is_replace_mode(
    in_sql         IN CLOB
  )
  RETURN BOOLEAN
  AS
    l_prfx           VARCHAR2(30);
    l_create_expr    VARCHAR2(30);
    l_table_expr     VARCHAR2(100);
    l_regexp         VARCHAR2(1000);
  BEGIN
    l_prfx := '#';
    l_create_expr := '^CREATE\s*';
    l_regexp := '('||l_create_expr||'\/\*'||l_prfx||'\s*OR\s+REPLACE\W)|'||
                '('||l_create_expr|| '--' ||l_prfx||'[ \t]*OR[ \t]*+REPLACE\W)';
    RETURN REGEXP_INSTR(in_sql, l_regexp, 1, 1, 0, 'imn') = 1;
  END is_replace_mode;

 -- Function returns currently executing ddl statement. It could be called only from DDL triggers
  FUNCTION ora_dict_ddl
  RETURN CLOB
  AS
    l_ddl_arr   dbms_standard.ora_name_list_t;
    l_ddl       CLOB;
    l_cnt       PLS_INTEGER;
  BEGIN
    l_cnt := ora_sql_txt(l_ddl_arr);
    IF l_ddl_arr IS NOT NULL THEN
      FOR i IN 1..l_cnt LOOP
        -- TRIM(CHR(0) is workaroung to remove trailing #0 symbol. This symbol breask down convertion into XML 
        l_ddl := l_ddl || TRIM(CHR(0) FROM l_ddl_arr(i));
      END LOOP;
    END IF;
    RETURN l_ddl;
  END ora_dict_ddl;

  -- Returns 'REPLACE' if there is #OR REPLACE hint in given DDL or if this parameter is turned on for session.
  -- Otherwise returns 'CREATE'. It could be called only from DDL triggers
  FUNCTION get_execution_mode
  RETURN VARCHAR2
  AS
  BEGIN
    IF is_replace_mode(ora_dict_ddl) THEN
      RETURN 'REPLACE';
    ELSE
      RETURN 'CREATE';
    END IF;
  END get_execution_mode;
  
  -- Main procedure is called from trigger
  PROCEDURE create_or_replace
  AS
  BEGIN
    BEGIN
      cort_job_pkg.start_job(
        in_action         => 'CREATE_OR_REPLACE',
        in_object_name    => ora_dict_obj_name,
        in_object_owner   => ora_dict_obj_owner,
        in_object_type    => ora_dict_obj_type,
        in_sql            => ora_dict_ddl,
        in_partition_pos  => ora_partition_pos
      );
    EXCEPTION
      WHEN OTHERS THEN 
        -- to hide error stack
        RAISE;
    END;
  END create_or_replace;
  

END cort_trg_pkg;
/