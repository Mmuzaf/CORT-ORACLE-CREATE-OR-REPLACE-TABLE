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
  Description: Schema standard installation script (without SQLPlus Extensions)
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  14.01.1 | Rustam Kafarov    | Removed dependencies on SQLPlus Extensions 
  ----------------------------------------------------------------------------------------------------------------------  
*/


DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*)
    INTO l_cnt 
    FROM user_tables 
   WHERE table_name = 'CORT_STAT';
    
  IF l_cnt = 0 THEN
    dbms_output.put_line('TABLE CORT_STAT');
    dbms_stats.create_stat_table(
      ownname          => USER,
      stattab          => 'CORT_STAT',
      global_temporary => TRUE
    );
  END IF;
END;
/

PROMPT TABLE CORT_JOBS

@DROP TABLE cort_jobs

CREATE TABLE cort_jobs(
  sid             NUMBER(10)      NOT NULL,
  action          VARCHAR2(30)    NOT NULL,
  status          VARCHAR2(30)    NOT NULL CHECK(status IN ('RUNNING','FAILED','SUCCESS')),
  job_schema      VARCHAR2(30)    NOT NULL,
  job_name        VARCHAR2(30)    NOT NULL,
  job_datetime    TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
  job_sid         NUMBER,
  object_type     VARCHAR2(30)    NOT NULL,
  object_owner    VARCHAR2(30)    NOT NULL,
  object_name     VARCHAR2(30)    NOT NULL,
  sql_text        CLOB            NOT NULL,  
  partition_pos   NUMBER,
  session_params  XMLTYPE,
  output          CLOB,
  error_code      NUMBER,
  error_message   VARCHAR2(4000),
  error_stack     VARCHAR2(4000),
  error_backtrace VARCHAR2(4000),
  call_stack      VARCHAR2(4000),
  cort_stack      VARCHAR2(4000),
  CONSTRAINT cort_jobs_sid_pk PRIMARY KEY (sid, status)
);

CREATE UNIQUE INDEX cort_jobs_object_name_uk ON cort_jobs(object_name, object_owner, DECODE(status,'RUNNING',0,sid));
  

PROMPT TABLE CORT_JOB_LOG

@DROP TABLE cort_job_log

CREATE TABLE cort_job_log(
  job_log_id      NUMBER          NOT NULL,
  job_log_time    TIMESTAMP       NOT NULL,
  sid             NUMBER,
  action          VARCHAR2(30),
  status          VARCHAR2(30),
  job_schema      VARCHAR2(30),
  job_name        VARCHAR2(30),
  object_type     VARCHAR2(30),
  object_owner    VARCHAR2(30),
  object_name     VARCHAR2(30),
  sql_text        CLOB,
  partition_pos   NUMBER,
  session_id      NUMBER,
  username        VARCHAR2(30),
  osuser          VARCHAR2(30),
  machine         VARCHAR2(64),
  terminal        VARCHAR2(16),
  program         VARCHAR2(64),
  session_params  XMLTYPE,
  output          CLOB,
  error_code      NUMBER,
  error_message   VARCHAR2(4000),
  error_stack     VARCHAR2(4000),
  error_backtrace VARCHAR2(4000),
  call_stack      VARCHAR2(4000),
  cort_stack      VARCHAR2(4000),
  CONSTRAINT cort_job_log_pk PRIMARY KEY(job_log_id) 
);


PROMPT TABLE CORT_LOG

@DROP TABLE cort_log

CREATE TABLE cort_log(
  log_id         NUMBER          NOT NULL,
  log_time       TIMESTAMP       NOT NULL,
  sid            NUMBER          NOT NULL,
  action         VARCHAR2(30),
  object_type    VARCHAR2(30),
  object_owner   VARCHAR2(30),
  object_name    VARCHAR2(30),
  package_name   VARCHAR2(30),
  proc_name      VARCHAR2(30),
  line_number    NUMBER,
  text           VARCHAR2(4000),
  params         CLOB,
  execution_time NUMBER(18,9),
  CONSTRAINT cort_log_pk PRIMARY KEY(log_id) 
);



--DROP TABLE cort_objects CASCADE CONSTRAINTS PURGE;

PROMPT TABLE CORT_OBJECTS

CREATE TABLE cort_objects(
  id                             NUMBER(15)    NOT NULL,
  object_owner                   VARCHAR2(30)  NOT NULL,
  object_name                    VARCHAR2(30)  NOT NULL,
  object_type                    VARCHAR2(30)  NOT NULL,
  start_time                     TIMESTAMP(9)  NOT NULL,
  end_time                       TIMESTAMP(9)  NOT NULL,
  sql_text                       CLOB,
  rollback_name                  VARCHAR2(30),
  prev_id                        NUMBER(15),
  del_flag                       VARCHAR2(1) CHECK(del_flag IS NULL OR del_flag = 'Y'),
  forward_ddl                    XMLTYPE,
  rollback_ddl                   XMLTYPE,
  application                    VARCHAR2(8),
  version                        VARCHAR2(6),
  CONSTRAINT cort_objects_pk
    PRIMARY KEY (id),
  CONSTRAINT cort_objects_uk
    UNIQUE (object_owner, object_type, object_name, end_time),
  CONSTRAINT cort_objects_prev_fk
    FOREIGN KEY(prev_id) REFERENCES cort_objects(id) ON DELETE CASCADE,
  CONSTRAINT cort_objects_prev_uk UNIQUE(prev_id)
);


PROMPT TABLE CORT_PARAMS

@DROP TABLE cort_params

CREATE TABLE cort_params (
  param_name      VARCHAR2(30)   NOT NULL,
  param_type      VARCHAR2(30)   NOT NULL,
  default_value   VARCHAR2(1000) NOT NULL,  
  CONSTRAINT cort_params_pk PRIMARY KEY (param_name),
  CONSTRAINT cort_params_name_chk CHECK(param_name = UPPER(param_name)),
  CONSTRAINT cort_params_type_chk CHECK(param_type IN ('BOOLEAN','NUMBER','VARCHAR2'))
);


PROMPT TABLE CORT_HINTS

@DROP TABLE cort_hints

CREATE TABLE cort_hints (
  hint            VARCHAR2(30)   NOT NULL,
  param_name      VARCHAR2(30)   NOT NULL,
  param_value     VARCHAR2(1000),  
  expression_flag VARCHAR2(1)    NOT NULL,
  CONSTRAINT cort_hints_pk PRIMARY KEY (hint)
);


CREATE OR REPLACE CONTEXT cort_context USING cort_exec_pkg;

@@cort_params.sql

@@cort_hints.sql

@DROP SEQUENCE cort_log_seq
CREATE SEQUENCE cort_log_seq;


@DROP SEQUENCE cort_obj_seq 
CREATE SEQUENCE cort_obj_seq;

