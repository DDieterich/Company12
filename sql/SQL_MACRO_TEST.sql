
--
-- SQL_MACRO Test
--
-- This script tests a permission problem with DB Links
--   in an SQL_MACRO used in a view.
--

--connect sys@//localhost:1521/CDB

-- Basic Setup
set linesize 2499
set trimspool on
set termout on
set verify off
set echo off
set timing on
set serveroutput on size unlimited format wrapped

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

-- Create 2 PDBs
alter session set container = "CDB$ROOT";
@create_pdb "tstpdb01"
@create_pdb "tstpdb02"

-- Setup TSTPDB01
alter session set container = "tstpdb01";
create user REMOTE_OWNER identified by "remote_owner" profile DEFAULT
   temporary tablespace TEMP default tablespace USERS
   quota 512M on USERS;
grant "CONNECT" to REMOTE_OWNER;
grant "RESOURCE" to REMOTE_OWNER;
grant select any dictionary to REMOTE_OWNER;
create table REMOTE_OWNER.tab1(c1 number);
insert into REMOTE_OWNER.tab1 (c1) values (1);
commit;
select * from REMOTE_OWNER.tab1;

-- Setup TSTPDB02
alter session set container = "tstpdb02";
create user LOCAL_OWNER identified by "local_owner" profile DEFAULT
   temporary tablespace TEMP default tablespace USERS
   quota 512M on USERS;
grant "CONNECT" to LOCAL_OWNER;
grant "RESOURCE" to LOCAL_OWNER;
grant select any dictionary to LOCAL_OWNER;
grant create view to LOCAL_OWNER;
grant create database link to LOCAL_OWNER;
create table LOCAL_OWNER.tab2 (c2 number);
insert into LOCAL_OWNER.tab2 (c2) values (2);
commit;
select * from LOCAL_OWNER.tab2;
create user BUILD_OWNER identified by "build_owner" profile DEFAULT
   temporary tablespace TEMP default tablespace USERS
   quota 512M on USERS;
grant "CONNECT" to BUILD_OWNER;
grant "RESOURCE" to BUILD_OWNER;
grant select any dictionary to BUILD_OWNER;
grant create any view to BUILD_OWNER;

-- Run Test01
connect "LOCAL_OWNER@//localhost:1521/tstpdb02"
drop database link dbl1;
create database link dbl1 connect to REMOTE_OWNER
   identified by "remote_owner" using '//localhost:1521/tstpdb01';
select * from REMOTE_OWNER.tab1@dbl1;
connect "BUILD_OWNER@//localhost:1521/tstpdb02"
create or replace view LOCAL_OWNER.vw1 as
   select * from REMOTE_OWNER.tab1@dbl1;
connect "LOCAL_OWNER@//localhost:1521/tstpdb02"
grant select on LOCAL_OWNER.vw1 to BUILD_OWNER;
select * from LOCAL_OWNER.vw1;

-- Run Test02
connect "LOCAL_OWNER@//localhost:1521/tstpdb02"
create or replace function LOCAL_OWNER.SQL_MACRO_TAB2
   return VARCHAR2 SQL_MACRO
is
begin
   return 'select * from tab2';
end SQL_MACRO_TAB2;
/
grant execute on LOCAL_OWNER.SQL_MACRO_TAB2 to BUILD_OWNER;
select SQL_MACRO_TAB2() from dual;
select * from SQL_MACRO_TAB2();
create or replace view vw2 as
   select * from SQL_MACRO_TAB2();
connect "BUILD_OWNER@//localhost:1521/tstpdb02"
create or replace view LOCAL_OWNER.vw2 as
   select * from SQL_MACRO_TXT();
connect "LOCAL_OWNER@//localhost:1521/tstpdb02"
select * from LOCAL_OWNER.vw2;

-- Run Test03
connect "LOCAL_OWNER@//localhost:1521/tstpdb02"
create or replace function LOCAL_OWNER.SQL_MACRO_TXT
   return NVARCHAR2 SQL_MACRO
is
begin
   return 'select * from dual';
   --return 'select * from REMOTE_OWNER.tab1@dbl1';
end SQL_MACRO_TXT;
/
select SQL_MACRO_TXT() from dual;
select DUMMY from dual;
select DUMMY from SQL_MACRO_TXT();
create or replace view vw2 as
   select * from SQL_MACRO_TXT();
connect "BUILD_OWNER@//localhost:1521/tstpdb02"
create or replace view LOCAL_OWNER.vw2 as
   select * from SQL_MACRO_TXT();
connect "LOCAL_OWNER@//localhost:1521/tstpdb02"
select * from LOCAL_OWNER.vw2;

-- Drop 2 DPBs
--ORA-01003: no statement parsed
alter session set container = "CDB$ROOT";
@drop_pdb "tstpdb01"
@drop_pdb "tstpdb02"
