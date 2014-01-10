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
  Description: Trigger to intercept table creations event
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

CREATE OR REPLACE TRIGGER cort_create_trg INSTEAD OF CREATE ON DATABASE
WHEN (
      (ora_dict_obj_type = 'TABLE') AND
      (ora_dict_obj_owner NOT IN ('SYS','SYSTEM')) AND
      (cort_trg_pkg.get_execution_mode() = 'REPLACE') AND
      (SYS_CONTEXT('CORT_CONTEXT','CREATE_OR_REPLACE_TABLE') IS NULL) 
     )
CALL cort_trg_pkg.create_or_replace
/
