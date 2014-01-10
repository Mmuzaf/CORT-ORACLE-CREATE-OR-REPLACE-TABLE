CREATE OR REPLACE PACKAGE cort_trg_pkg
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

  -- Function returns currently executing ddl statement. It could be called only from DDL triggers
  FUNCTION ora_dict_ddl
  RETURN CLOB;

  -- Returns 'REPLACE' if there is #OR REPLACE hint in given DDL or if this parameter is turned on for session.
  -- Otherwise returns 'CREATE'. It could be called only from DDL triggers
  FUNCTION get_execution_mode
  RETURN VARCHAR2;
  
  -- Main procedure is called from trigger 
  PROCEDURE create_or_replace; 
   
END cort_trg_pkg;
/