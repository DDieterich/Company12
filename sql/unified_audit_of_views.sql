
--
-- Unified Audit of View Testing
--
-- This script tests the use of Unified Audit to track
--   SELECT FROM VIEW statements.
--
-- 12c Demo: https://oracle-base.com/articles/12c/auditing-enhancements-12cr1
-- 19c Updates: https://oracle-base.com/articles/19c/auditing-enhancements-19c
--
-- NOTE: Tested on Oracle 21c.
--   The "unified_audit_trail" view includes a new OBJECT_TYPE column.
--

-- SQL*Plus Setup
set linesize 2499
set trimspool on
set termout on
set verify off
set echo off

-- Connect to SYS@CDB for Pluggable Database work
connect "sys@//localhost:1521/EE213CDB"
set serveroutput on size unlimited format wrapped
set timing on

-- Confirm Environment
select 'user: ' || u.username ||
       ', db: ' || d.name ||
       ', con: ' || sys_context('USERENV', 'CON_NAME') ||
       ', tstmp: ' || systimestamp   CONNECTION
 from  v$database d
 cross join user_users u;
show pdbs
select name from v$services;
select * from v$version;

-- Traditional Audit must be enabled for Mixed Mode Audit to function
-- Needed to enable Unified Audit without compiling database executable
alter system set audit_trail = 'db' scope=spfile;
shutdown immediate
startup

-- Show Auditing Setting at CDB Level
--select * from AUDITABLE_SYSTEM_ACTIONS;
--select * from AUDITABLE_OBJECT_ACTIONS;
--select name||' ('||privilege||', '||property||')' from system_privilege_map order by name;
--select * from all_def_audit_opts;
select * from v$parameter
 where regexp_like(name,'audit','i')
 order by name;
select * from v$option
 where regexp_like(parameter,'audit','i')
 order by parameter;

-- Create Pluggable Database
create pluggable database "tstpdb01"
  admin user "C12ADMIN"
  identified by "C12Admin_Password"
  default tablespace users datafile 'users_datafile' size 5M autoextend on
  FILE_NAME_CONVERT = ('pdbseed', 'tstpdb01')
  STORAGE UNLIMITED
  TEMPFILE REUSE;
alter pluggable database "tstpdb01" open;
select * from v$pdbs;

-- Connect to SYS@PDB to setup VIEW_OWNER
alter session set container = tstpdb01;
set serveroutput on size unlimited format wrapped
set timing on
alter profile "DEFAULT" limit password_life_time unlimited;

-- setup VIEW_OWNER
create user VIEW_OWNER
   identified by "view_owner"
   profile DEFAULT
   temporary tablespace TEMP
   default tablespace USERS
   quota 512M on USERS;
grant create session to VIEW_OWNER;
grant create view to VIEW_OWNER;
create view view_owner.test_view_01 as select * from dual;
create view view_owner.test_view_02 as select * from dual;

-- Setup Audit Policy
create audit policy VIEW_SELECT_TEST_01
  actions select on view_owner.test_view_01
         ,select on view_owner.test_view_02
  only toplevel;
comment on audit policy VIEW_SELECT_TEST_01
  is 'Test auditing of SELECT FROM VIEW';
audit policy VIEW_SELECT_TEST_01;
--noaudit policy VIEW_SELECT_TEST_01;
-- Auditing Context is a Global Setting
audit context namespace USERENV attributes SESSION_EDITION_NAME;
-- Reconnect for "audit context namespace" to take effect
--noaudit context namespace USERENV attributes SESSION_EDITION_NAME;

-- Confirm Audit Policy
select sys_context('USERENV', 'SESSION_EDITION_NAME') from dual;
select * from audit_unified_contexts;
select * from audit_unified_enabled_policies;
-- This query takes about 80 seconds to run (laptop database).
select policy_name, count(distinct object_schema) schemas,
       oracle_supplied, count(*) num
 from  audit_unified_policies
 group by policy_name, oracle_supplied
 order by policy_name, oracle_supplied;
-- This query takes about 40 seconds to run (laptop database).
select * from audit_unified_policies
 where policy_name = 'VIEW_SELECT_TEST_01';
select * from audit_unified_policy_comments;

-- Test Unified Audit at PDB Level
select * from view_owner.test_view_01;
select * from view_owner.test_view_02;
--If you are in delayed-write mode, you may need to flush
--  the audit trail before you can see the audit records.
--EXEC DBMS_AUDIT_MGMT.flush_unified_audit_trail;
select * from unified_audit_trail
 order by event_timestamp_utc desc;

-- Setup User View of Audit Trail
--drop view view_select_test_01_log;
create view view_select_test_01_log as
  select * from UNIFIED_AUDIT_TRAIL
   --where regexp_like(UNIFIED_AUDIT_POLICIES,'VIEW_SELECT_TEST_01');
   where object_schema = 'VIEW_OWNER'
    and  action_name = 'SELECT';
grant select on view_select_test_01_log to VIEW_OWNER;
create public synonym view_select_test_01_log for view_select_test_01_log;
select * from view_select_test_01_log;

-- Test Unified Audit Results at CDB Level
alter session set container = "CDB$ROOT";
set serveroutput on size unlimited format wrapped
set timing on
select * from audit_unified_enabled_policies;
select * from CDB_UNIFIED_AUDIT_TRAIL
 where object_schema = 'VIEW_OWNER'
  and  action_name = 'SELECT';

-- Login as View Owner and
connect "view_owner/view_owner@//localhost:1521/TSTPDB01"
show user
show con_name
select * from view_owner.test_view_01;
select * from view_owner.test_view_02 where bogus = 'error';
select * from view_select_test_01_log;
select event_timestamp_utc
      ,return_code
      ,object_schema
      ,object_name
      ,object_type               -- Starting in 21c
      ,action_name
      --,sql_text                -- CLOB
      --,sql_binds               -- PL/SQL Only?
      ,application_contexts
      ,dbusername
      ,authentication_type
      ,scn
      ,sessionid
      ,instance_id
      ,db_unique_name
      ,client_program_name
      ,os_username
      ,userhost
      ,os_process
      ,audit_type
      ,unified_audit_policies
 from view_select_test_01_log
 order by event_timestamp_utc desc;
--"EVENT_TIMESTAMP_UTC","RETURN_CODE","OBJECT_SCHEMA","OBJECT_NAME","OBJECT_TYPE","ACTION_NAME","APPLICATION_CONTEXTS","DBUSERNAME","AUTHENTICATION_TYPE","SCN","SESSIONID","INSTANCE_ID","DB_UNIQUE_NAME","CLIENT_PROGRAM_NAME","OS_USERNAME","USERHOST","OS_PROCESS","AUDIT_TYPE","UNIFIED_AUDIT_POLICIES"
--08/08/25 15:55:08.404668000,904,"VIEW_OWNER","TEST_VIEW_02","VIEW","SELECT","(USERENV,SESSION_EDITION_NAME=ORA$BASE)","VIEW_OWNER","(TYPE=(DATABASE));(CLIENT ADDRESS=((PROTOCOL=tcp)(HOST=172.19.0.1)(PORT=54476)));",45681835,496222069,1,"EE213CDB","Oracle SQL Developer for VS Code/25.2.2","Duane","DESKTOP-O834E1S","48227","Standard","VIEW_SELECT_TEST_01"
--08/08/25 15:55:05.925789000,0,"VIEW_OWNER","TEST_VIEW_01","VIEW","SELECT","(USERENV,SESSION_EDITION_NAME=ORA$BASE)","VIEW_OWNER","(TYPE=(DATABASE));(CLIENT ADDRESS=((PROTOCOL=tcp)(HOST=172.19.0.1)(PORT=54476)));",45681832,496222069,1,"EE213CDB","Oracle SQL Developer for VS Code/25.2.2","Duane","DESKTOP-O834E1S","48227","Standard","VIEW_SELECT_TEST_01"
--08/08/25 15:54:45.505441000,0,"VIEW_OWNER","TEST_VIEW_02","VIEW","SELECT","(USERENV,SESSION_EDITION_NAME=ORA$BASE)","SYS","(TYPE=(DATABASE));(CLIENT ADDRESS=((PROTOCOL=tcp)(HOST=172.19.0.1)(PORT=48974)));",45681807,2684647333,1,"EE213CDB","Oracle SQL Developer for VS Code/25.2.2","Duane","DESKTOP-O834E1S","48072","Standard","VIEW_SELECT_TEST_01"
--08/08/25 15:54:43.899618000,0,"VIEW_OWNER","TEST_VIEW_01","VIEW","SELECT","(USERENV,SESSION_EDITION_NAME=ORA$BASE)","SYS","(TYPE=(DATABASE));(CLIENT ADDRESS=((PROTOCOL=tcp)(HOST=172.19.0.1)(PORT=48974)));",45681804,2684647333,1,"EE213CDB","Oracle SQL Developer for VS Code/25.2.2","Duane","DESKTOP-O834E1S","48072","Standard","VIEW_SELECT_TEST_01"

-- Drop PDB
alter pluggable database "tstpdb01" close immediate instances=all;
drop pluggable database "tstpdb01" including datafiles;
