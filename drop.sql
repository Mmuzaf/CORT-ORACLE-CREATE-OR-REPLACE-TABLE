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
  Description: drop object only if it exists
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01.1 | Rustam Kafarov    | Smart dropping of object
  ----------------------------------------------------------------------------------------------------------------------  
*/

-- Params:
-- 1 - object type
-- 2 - object name

SET FEEDBACK OFF

DECLARE
  l_cnt NUMBER;
  l_sql VARCHAR2(32767);
BEGIN  
  SELECT COUNT(*)
    INTO l_cnt 
    FROM user_objects
   WHERE object_type = UPPER('&1')
     AND object_name = UPPER('&2');
  IF l_cnt = 1 THEN
    l_sql := 'DROP &1 &2';
    dbms_output.put_line(l_sql);
    EXECUTE IMMEDIATE l_sql;
  END IF;   
END;     
/

SET FEEDBACK ON