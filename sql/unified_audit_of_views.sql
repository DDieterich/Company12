
--
-- Unified Audit of View Testing
--
-- This script tests the use of Unified Audit to track
--   SELECT FROM VIEW statements.
--
-- 12c Demo: https://oracle-base.com/articles/12c/auditing-enhancements-12cr1
-- 19c Updates: https://oracle-base.com/articles/19c/auditing-enhancements-19c

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

-- Show Auditing Settings at PDB Level
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
alter system set audit_trail = 'db' scope=spfile;
-- restart database

-- Setup Audit Policy
create audit policy VIEW_SELECT_TEST_01
  actions select on view_owner.test_view_01
         ,select on view_owner.test_view_02
  only toplevel;
comment on audit policy VIEW_SELECT_TEST_01
  is 'Test auditing of SELECT FROM VIEW';
audit policy VIEW_SELECT_TEST_01;
noaudit policy VIEW_SELECT_TEST_01;
audit policy VIEW_SELECT_TEST_01;

-- Confirm Audit Policy
select * from audit_unified_contexts; -- No Rows
select * from audit_unified_enabled_policies;
select policy_name, count(distinct object_schema) schemas,
       oracle_supplied, count(*) num
 from  audit_unified_policies
 group by policy_name, oracle_supplied
 order by policy_name, oracle_supplied;
select * from audit_unified_policies
 where policy_name = 'VIEW_SELECT_TEST_01';
select * from audit_unified_policy_comments;

-- Test Unified Audit as PDB Level
select * from view_owner.test_view_01;
select * from view_owner.test_view_02;
--If you are in delayed-write mode, you may need to flush
--  the audit trail before you can see the audit records.
EXEC DBMS_AUDIT_MGMT.flush_unified_audit_trail;
select count(*) from unified_audit_trail;
select * from unified_audit_trail;
select count(*) from AUDSYS.AUD$UNIFIED;
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

-- Test Unified Audit Results at CDB Level
alter session set container = "CDB$ROOT";
set serveroutput on size unlimited format wrapped
set timing on
select * from audit_unified_enabled_policies;
--If you are in delayed-write mode, you may need to flush
--  the audit trail before you can see the audit records.
EXEC DBMS_AUDIT_MGMT.flush_unified_audit_trail;
select count(*) from CDB_UNIFIED_AUDIT_TRAIL;
select * from CDB_UNIFIED_AUDIT_TRAIL;
