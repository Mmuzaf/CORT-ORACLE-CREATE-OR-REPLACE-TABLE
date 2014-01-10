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
  Description: Grants and public synonyms for CORT objects
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

GRANT EXECUTE ON cort_pkg     TO PUBLIC;
GRANT SELECT  ON cort_log     TO PUBLIC;
GRANT SELECT  ON cort_job_log TO PUBLIC;
GRANT SELECT  ON cort_jobs    TO PUBLIC;
GRANT SELECT  ON cort_objects TO PUBLIC;

CREATE OR REPLACE PUBLIC SYNONYM cort_pkg     FOR cort_pkg;
CREATE OR REPLACE PUBLIC SYNONYM cort_log     FOR cort_log;
CREATE OR REPLACE PUBLIC SYNONYM cort_job_log FOR cort_job_log; 
CREATE OR REPLACE PUBLIC SYNONYM cort_jobs    FOR cort_jobs; 
CREATE OR REPLACE PUBLIC SYNONYM cort_objects FOR cort_objects; 
 

 
