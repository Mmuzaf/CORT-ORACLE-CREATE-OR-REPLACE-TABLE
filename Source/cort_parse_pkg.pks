CREATE OR REPLACE PACKAGE cort_parse_pkg
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
  Description: Parser utility for SQL commands and CORT hints
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

  FUNCTION is_simple_name(in_name IN VARCHAR2)
  RETURN BOOLEAN;

  -- parses cort hints
  PROCEDURE parse_cort_hints(
    in_hint_string IN VARCHAR2,
    io_params_rec  IN OUT NOCOPY cort_params_pkg.gt_params_rec
  );
  
  -- parses SQL
  PROCEDURE initial_parse_sql(
    in_sql           IN CLOB,
    in_operation     IN VARCHAR2,-- CREATE/DROP
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2,
    in_object_owner  IN VARCHAR2,  
    in_partition_pos IN NUMBER,
    io_params_rec    IN OUT NOCOPY cort_params_pkg.gt_params_rec
  );

  -- replaces table name and all names of existing depending objects (constraints, log groups, indexes, lob segments) 
  PROCEDURE replace_names(
    in_table_rec IN cort_exec_pkg.gt_table_rec,
    out_sql      OUT NOCOPY CLOB 
  );
  
  -- return original name for renamed object. If it wasn't rename return current name 
  FUNCTION get_original_name(
    in_object_type  IN VARCHAR2,
    in_object_name  IN VARCHAR2
  )
  RETURN VARCHAR2;

  -- parses sql
  PROCEDURE parse_create_table_sql(
    in_sql        IN CLOB,
    io_table_rec  IN OUT NOCOPY cort_exec_pkg.gt_table_rec,
    io_params_rec IN OUT NOCOPY cort_params_pkg.gt_params_rec
  );

  -- replaces partitions definition in original_sql
  PROCEDURE replace_partitions_sql(
    io_sql           IN OUT NOCOPY CLOB,
    in_partition_sql IN CLOB
  );

  -- parses drop command and returns purge clause
  PROCEDURE parse_purge_clause(
    out_purge OUT VARCHAR2
  );
  
END cort_parse_pkg;
/