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
  Description: Master install script     
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  14.01.1 | Rustam Kafarov    | Removed call of cort_schema.sql
  ----------------------------------------------------------------------------------------------------------------------  
*/

@@run_script.sql cort_params_pkg.pks
@@run_script.sql cort_log_pkg.pks
@@run_script.sql cort_exec_pkg.pks
@@run_script.sql cort_comp_pkg.pks
@@run_script.sql cort_parse_pkg.pks
@@run_script.sql cort_xml_pkg.pks
@@run_script.sql cort_aux_pkg.pks
@@run_script.sql cort_pkg.pks
@@run_script.sql cort_trg_pkg.pks
@@run_script.sql cort_job_pkg.pks

@@run_script.sql cort_params_pkg.pkb
@@run_script.sql cort_log_pkg.pkb
@@run_script.sql cort_exec_pkg.pkb
@@run_script.sql cort_comp_pkg.pkb
@@run_script.sql cort_parse_pkg.pkb
@@run_script.sql cort_xml_pkg.pkb
@@run_script.sql cort_aux_pkg.pkb
@@run_script.sql cort_pkg.pkb
@@run_script.sql cort_trg_pkg.pkb
@@run_script.sql cort_job_pkg.pkb

@@run_script.sql cort_create_trg.trg

@@cort_grants.sql

