
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

-- Traditional Audit must be enabled for Mixed Mode Audit to function
-- Needed do enable Unified Audit without compiling database executable
alter system set audit_trail = 'db' scope=spfile;
-- restart database

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

-- Confirm Audit Policy
select * from audit_unified_contexts; -- No Rows
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

-- Test Unified Audit as PDB Level
select * from view_owner.test_view_01;
select * from view_owner.test_view_02;
--If you are in delayed-write mode, you may need to flush
--  the audit trail before you can see the audit records.
--EXEC DBMS_AUDIT_MGMT.flush_unified_audit_trail;
select * from unified_audit_trail -- where object_name = 'TEST_VIEW_02';
select * from AUDSYS.AUD$UNIFIED;

-- Setup User View of Audit Trail
create view view_select_test_01_log as
  select * from UNIFIED_AUDIT_TRAIL
  where regexp_like(UNIFIED_AUDIT_POLICIES,'VIEW_SELECT_TEST_01');
select * from view_select_test_01_log;
drop view view_select_test_01_log;
create view view_select_test_01_log as
  select * from UNIFIED_AUDIT_TRAIL
  where object_schema = 'VIEW_OWNER'
   and  action_name = 'SELECT'
   and  audit_type = 'Standard';
select * from view_select_test_01_log;

--"AUDIT_TYPE","SESSIONID","PROXY_SESSIONID","OS_USERNAME","USERHOST","TERMINAL","INSTANCE_ID","DBID","AUTHENTICATION_TYPE","DBUSERNAME","DBPROXY_USERNAME","EXTERNAL_USERID","GLOBAL_USERID","CLIENT_PROGRAM_NAME","DBLINK_INFO","XS_USER_NAME","XS_SESSIONID","ENTRY_ID","STATEMENT_ID","EVENT_TIMESTAMP","EVENT_TIMESTAMP_UTC","ACTION_NAME","RETURN_CODE","OS_PROCESS","TRANSACTION_ID","SCN","EXECUTION_ID","OBJECT_SCHEMA","OBJECT_NAME","SQL_TEXT","SQL_BINDS","APPLICATION_CONTEXTS","CLIENT_IDENTIFIER","NEW_SCHEMA","NEW_NAME","OBJECT_EDITION","SYSTEM_PRIVILEGE_USED","SYSTEM_PRIVILEGE","AUDIT_OPTION","OBJECT_PRIVILEGES","ROLE","TARGET_USER","EXCLUDED_USER","EXCLUDED_SCHEMA","EXCLUDED_OBJECT","CURRENT_USER","ADDITIONAL_INFO","UNIFIED_AUDIT_POLICIES","FGA_POLICY_NAME","XS_INACTIVITY_TIMEOUT","XS_ENTITY_TYPE","XS_TARGET_PRINCIPAL_NAME","XS_PROXY_USER_NAME","XS_DATASEC_POLICY_NAME","XS_SCHEMA_NAME","XS_CALLBACK_EVENT_TYPE","XS_PACKAGE_NAME","XS_PROCEDURE_NAME","XS_ENABLED_ROLE","XS_COOKIE","XS_NS_NAME","XS_NS_ATTRIBUTE","XS_NS_ATTRIBUTE_OLD_VAL","XS_NS_ATTRIBUTE_NEW_VAL","DV_ACTION_CODE","DV_ACTION_NAME","DV_EXTENDED_ACTION_CODE","DV_GRANTEE","DV_RETURN_CODE","DV_ACTION_OBJECT_NAME","DV_RULE_SET_NAME","DV_COMMENT","DV_FACTOR_CONTEXT","DV_OBJECT_STATUS","OLS_POLICY_NAME","OLS_GRANTEE","OLS_MAX_READ_LABEL","OLS_MAX_WRITE_LABEL","OLS_MIN_WRITE_LABEL","OLS_PRIVILEGES_GRANTED","OLS_PROGRAM_UNIT_NAME","OLS_PRIVILEGES_USED","OLS_STRING_LABEL","OLS_LABEL_COMPONENT_TYPE","OLS_LABEL_COMPONENT_NAME","OLS_PARENT_GROUP_NAME","OLS_OLD_VALUE","OLS_NEW_VALUE","RMAN_SESSION_RECID","RMAN_SESSION_STAMP","RMAN_OPERATION","RMAN_OBJECT_TYPE","RMAN_DEVICE_TYPE","DP_TEXT_PARAMETERS1","DP_BOOLEAN_PARAMETERS1","DP_WARNINGS1","DIRECT_PATH_NUM_COLUMNS_LOADED","RLS_INFO","KSACL_USER_NAME","KSACL_SERVICE_NAME","KSACL_SOURCE_LOCATION","PROTOCOL_SESSION_ID","PROTOCOL_RETURN_CODE","PROTOCOL_ACTION_NAME","PROTOCOL_USERHOST","PROTOCOL_MESSAGE","DB_UNIQUE_NAME","OBJECT_TYPE"
--"Standard",3365856669,0,"Duane","DESKTOP-O834E1S","unknown",1,387175567,"(TYPE=(DATABASE));(CLIENT ADDRESS=((PROTOCOL=tcp)(HOST=172.19.0.1)(PORT=37342)));","SYS","","","","Oracle SQL Developer for VS Code/25.2.2","","",,6,59,07/08/25 18:05:20.330236000,07/08/25 23:05:20.330236000,"SELECT",0,"7097",0000000000000000,45546260,"JC-NSaUCChczhWs_mZRlpQ","VIEW_OWNER","TEST_VIEW_01","select * from view_owner.test_view_01
--"Standard",3365856669,0,"Duane","DESKTOP-O834E1S","unknown",1,387175567,"(TYPE=(DATABASE));(CLIENT ADDRESS=((PROTOCOL=tcp)(HOST=172.19.0.1)(PORT=37342)));","SYS","","","","Oracle SQL Developer for VS Code/25.2.2","","",,7,60,07/08/25 18:05:21.776704000,07/08/25 23:05:21.776704000,"SELECT",0,"7097",0000000000000000,45546278,"Y4yMMix9pbzDT7MN8WfKyA","VIEW_OWNER","TEST_VIEW_02","select * from view_owner.test_view_02

-- Test Unified Audit Results at CDB Level
alter session set container = "CDB$ROOT";
set serveroutput on size unlimited format wrapped
set timing on
select * from audit_unified_enabled_policies;
select * from CDB_UNIFIED_AUDIT_TRAIL;

-- Drop PDB
alter pluggable database "tstpdb01" close immediate instances=all;
drop pluggable database "tstpdb01" including datafiles;
