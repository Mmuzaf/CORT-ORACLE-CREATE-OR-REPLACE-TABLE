CREATE OR REPLACE PACKAGE cort_pkg
AUTHID CURRENT_USER
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

  /* This package will be granted to public */
  
  SUBTYPE gt_params_rec IS cort_params_pkg.gt_params_rec;   

  TYPE gt_param_rec IS RECORD(
    name       VARCHAR2(30),
    type       VARCHAR2(30),
    value      VARCHAR2(4000)
  );

  TYPE gt_params IS TABLE OF gt_param_rec;

  FUNCTION param(
    in_name  IN VARCHAR2,
    in_value IN VARCHAR2
  )
  RETURN gt_param_rec;
  
  FUNCTION param(
    in_name  IN VARCHAR2,
    in_value IN NUMBER
  )
  RETURN gt_param_rec;

  FUNCTION param(
    in_name  IN VARCHAR2,
    in_value IN BOOLEAN
  )
  RETURN gt_param_rec;

  -- getters for session params
  FUNCTION get_params
  RETURN gt_params_rec;

  FUNCTION get_param_value(
    in_param_name   IN VARCHAR2
  )
  RETURN VARCHAR2;
  
  FUNCTION get_param_bool_value(
    in_param_name   IN VARCHAR2
  )
  RETURN BOOLEAN;

  -- setters for session params
  PROCEDURE set_param_value(
    in_param_name   IN VARCHAR2,
    in_param_value  IN NUMBER
  );

  PROCEDURE set_param_value(
    in_param_name   IN VARCHAR2,
    in_param_value  IN VARCHAR2
  );
  
  PROCEDURE set_param_value(
    in_param_name   IN VARCHAR2,
    in_param_value  IN BOOLEAN
  );
  
  -- Procedure is called from job 
  PROCEDURE execute_action(
    in_sid IN NUMBER
  );

  -- Rollback the latest change for given table
  PROCEDURE rollback_table(
    in_table_name  IN VARCHAR2,
    in_owner_name  IN VARCHAR2,
    in_params      IN gt_params 
  );
  
  -- Rollback the latest change for given table (overloaded)
  PROCEDURE rollback_table(
    in_table_name  IN VARCHAR2,
    in_owner_name  IN VARCHAR2 DEFAULT USER,
    in_echo        IN BOOLEAN DEFAULT NULL,  -- NULL - take from session param 
    in_test        IN BOOLEAN DEFAULT NULL   -- NULL - take from session param
  );
  
  -- enable CORT
  PROCEDURE enable_cort;
  
  -- disable CORT
  PROCEDURE disable_cort;
  
  -- get CORt status (ENABLED/DISABLED)
  FUNCTION get_cort_status
  RETURN VARCHAR2;
  
END cort_pkg;
/