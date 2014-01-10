CREATE OR REPLACE PACKAGE cort_params_pkg 
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
  Description: Type and API for main application parameters
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

  TYPE gt_params_rec IS RECORD(
   application             VARCHAR2(8),
   version                 VARCHAR2(8),
   alias                   VARCHAR2(30),
   parallel                NUMBER(5,0),
   debug                   BOOLEAN,
   echo                    BOOLEAN,
   log                     BOOLEAN,
   test                    BOOLEAN,
   force_recreate          BOOLEAN,
   force_move              BOOLEAN,
   rollback                BOOLEAN,
   physical_attr           BOOLEAN,
   keep_data               BOOLEAN,
   keep_refs               BOOLEAN,
   validate_refs           BOOLEAN,
   keep_bad_refs           BOOLEAN,
   keep_privs              BOOLEAN,
   keep_indexes            BOOLEAN,
   keep_triggers           BOOLEAN,
   keep_policies           BOOLEAN,
   keep_comments           BOOLEAN,
   keep_stats              BOOLEAN,
   keep_partitions         BOOLEAN,
   keep_subpartitions      BOOLEAN,
   keep_temp_table         BOOLEAN
  );
  
  -- convert BOOLEAN to VARCHAR2  
  FUNCTION bool_to_str(in_value IN BOOLEAN) 
  RETURN VARCHAR2;
  
  -- convert VARCHAR2 to BOOLEAN
  FUNCTION str_to_bool(in_value IN VARCHAR2) 
  RETURN BOOLEAN;

  -- setter for dynamic SQL - for intenal use only!!!
  PROCEDURE set_params_rec(in_params_rec IN gt_params_rec);
  
  -- getter for dynamic SQL - for intenal use only!!!
  FUNCTION get_params_rec
  RETURN gt_params_rec;

  -- return initialized record
  FUNCTION get_default_rec
  RETURN gt_params_rec;


  FUNCTION get_param_type(in_param_name IN VARCHAR2)
  RETURN VARCHAR2;
  
  FUNCTION get_param_value(
    in_params_rec IN gt_params_rec,
    in_param_name IN VARCHAR2
  )
  RETURN VARCHAR2;
  
  PROCEDURE set_param_value(
    io_params_rec  IN OUT NOCOPY gt_params_rec,
    in_param_name  IN VARCHAR2,
    in_param_value IN VARCHAR2
  );
  
END cort_params_pkg;
/
