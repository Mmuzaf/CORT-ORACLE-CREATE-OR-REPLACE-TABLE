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
  Description: standard install script. To install call: sqlplus /nolog @install.sql
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  14.01.1 | Rustam Kafarov    | Removed dependencies on SQLPlus Extensions
  ----------------------------------------------------------------------------------------------------------------------  
*/

SET SERVEROUTPUT ON
SET VERIFY OFF
WHENEVER SQLERROR EXIT
WHENEVER OSERROR EXIT

SPOOL install.log

PROMPT Enter Database service/instance name
ACCEPT db_inst CHAR PROMPT "[orcl] > " DEFAULT "orcl"

PROMPT Log as SYS
PROMPT Enter SYS password
ACCEPT sys_psw CHAR PROMPT "> " DEFAULT "sys" HIDE 

SPOOL OFF
CONNECT SYS/&sys_psw@&db_inst AS SYSDBA 

SET SERVEROUTPUT ON
UNDEFINE sys_psw
SET FEEDBACK OFF
SPOOL install.log APPEND

SET TERM OFF

VARIABLE rel VARCHAR2(10)

EXEC :rel := dbms_db_version.version||'.'||dbms_db_version.release

COLUMN release NEW_VALUE oracle_version NOPRINT

SELECT :rel AS release
  FROM DUAL;

SPOOL OFF
SET TERM ON
SPOOL install.log APPEND

PROMPT Creating CORT Schema
DEFINE recreate_flg = "?"

PROMPT Enter user for CORT schema
ACCEPT cort_user CHAR PROMPT "[CORT] > " DEFAULT "CORT" 

PROMPT Enter password for CORT user
ACCEPT cort_psw CHAR PROMPT "[cort] > " DEFAULT "cort" HIDE

COLUMN cort_exists NEW_VALUE _cort_exists NOPRINT

SET TERM OFF
SPOOL OFF

SELECT DECODE(COUNT(*), 0, 'dummy.sql', 'accept_yn.sql') AS cort_exists 
  FROM ALL_USERS 
 WHERE username = UPPER('&cort_user');

SPOOL install.log APPEND
SET TERM ON

@&_cort_exists

BEGIN
  IF UPPER('&recreate_flg') = 'Y' THEN
    -- display first
    dbms_output.put_line('Dropping existing user &cort_user ...');
  END IF;
END;
/    

BEGIN
  IF UPPER('&recreate_flg') = 'Y' THEN
    -- then start the actual dropping
    EXECUTE IMMEDIATE 'DROP USER &cort_user CASCADE';
  END IF;
END;
/    

DECLARE
  l_cnt PLS_INTEGER;
BEGIN
  SELECT COUNT(*)
    INTO l_cnt 
    FROM ALL_USERS 
   WHERE username = UPPER('&cort_user');
  IF l_cnt = 0 THEN
    dbms_output.put_line('Creating user &cort_user...');
    EXECUTE IMMEDIATE 'CREATE USER &cort_user IDENTIFIED BY "&cort_psw"';
  END IF;
END;
/

SET FEEDBACK ON

-- drop cort triggers

BEGIN
  FOR x IN (SELECT trigger_name FROM ALL_TRIGGERS 
             WHERE OWNER = '&cort_user') LOOP
    EXECUTE IMMEDIATE 'DROP TRIGGER "&cort_user"."'||x.trigger_name||'"';         
  END LOOP;           
END;
/
  
@SYS\&oracle_version\cort_all_constraints.sql
@SYS\&oracle_version\cort_all_lob_partitions.sql
@SYS\&oracle_version\cort_all_lob_templates.sql
@SYS\&oracle_version\cort_all_part_lobs.sql

@SYS\cort_user.sql

SPOOL OFF

CONNECT &cort_user/&cort_psw@&db_inst

SPOOL install.log APPEND

WHENEVER SQLERROR CONTINUE
WHENEVER OSERROR CONTINUE

@"..\PLSQL Utilities\Source\arrays.pks"
@"..\PLSQL Utilities\Source\partition_utils.pks"
@"..\PLSQL Utilities\Source\partition_utils.pkb"
@"..\PLSQL Utilities\Source\xml_utils.pks"
@"..\PLSQL Utilities\Source\xml_utils.pkb"

@@Source\cort_schema.sql
@@Source\cort_install.sql

PROMPT Installation complete
PROMPT 

SPOOL OFF

EXIT