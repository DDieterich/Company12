
--
-- Unified Audit of View Testing
--
-- This script tests the use of Unified Audit to track
--   SELECT FROM VIEW statements.
--

-- Basic Setup
set linesize 2499
set trimspool on
set termout on
set verify off
set echo off

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

-- Create Pluggable Database
create pluggable database "tstpdb01"
  admin user "C12ADMIN" identified by "C12Admin_Password"
  default tablespace users datafile 'users_datafile' size 5M autoextend on
  FILE_NAME_CONVERT = ('pdbseed', 'tstpdb01')
  STORAGE UNLIMITED TEMPFILE REUSE;
alter pluggable database "tstpdb01" open;
select * from v$pdbs;

-- Setup VIEW_OWNER@TSTPDB01
alter session set container = tstpdb01;
set serveroutput on size unlimited format wrapped
set timing on
alter profile "DEFAULT" limit password_life_time unlimited;
create user VIEW_OWNER identified by "view_owner" profile DEFAULT
   temporary tablespace TEMP default tablespace USERS
   quota 512M on USERS;
grant create session to VIEW_OWNER;
grant alter session to VIEW_OWNER;
grant set container to VIEW_OWNER;
grant create view to VIEW_OWNER;
create view view_owner.test_view_01 as select * from dual;
create view view_owner.test_view_02 as select * from dual;

-- Setup/Test Unified Audit
create audit policy VIEW_SELECT_TEST_01
  actions select on view_owner.test_view_01
  only toplevel;
audit policy VIEW_SELECT_TEST_01;
select * from unified_audit_trail;
select * from view_owner.test_view_01;
select * from view_owner.test_view_02;
select * from unified_audit_trail;

select * from v$option order by parameter;
alter session set container = "CDB$ROOT";
