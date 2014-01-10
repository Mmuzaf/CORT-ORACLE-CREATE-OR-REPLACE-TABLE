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

GRANT CREATE SESSION TO &cort_user;
GRANT CREATE TABLE TO &cort_user;
GRANT CREATE VIEW TO &cort_user;
GRANT CREATE PROCEDURE TO &cort_user;
GRANT CREATE SEQUENCE TO &cort_user;
GRANT CREATE TYPE TO &cort_user;
GRANT CREATE TRIGGER TO &cort_user;
GRANT ADMINISTER DATABASE TRIGGER TO &cort_user;

GRANT CREATE PUBLIC SYNONYM TO &cort_user;
GRANT UNLIMITED TABLESPACE TO &cort_user;

GRANT CREATE ANY CONTEXT TO &cort_user;
GRANT SELECT ANY DICTIONARY to &cort_user;

GRANT CREATE ANY JOB TO &cort_user;
GRANT ANALYZE ANY TO &cort_user;

GRANT SELECT ON v_$session TO &cort_user;
