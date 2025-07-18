
--
-- Create PDBs
--

--connect sys@//localhost:1521/CDB

-- Setup and Confirm Connection
set linesize 2499
set trimspool on
set termout on
set verify off
set echo off
set timing on
set serveroutput on size unlimited format wrapped
select 'user: ' || u.username ||
       ', db: ' || d.name ||
       ', con: ' || sys_context('USERENV', 'CON_NAME') ||
       ', tstmp: ' || systimestamp   CONNECTION
 from  v$database d
 cross join user_users u;
show pdbs

-- Create 2 PDBs
@create_pdb "tstpdb01"
@create_pdb "tstpdb02"

-- Setup Test Users
alter session set container = "tstpdb01";
create user 
alter session set container = "tstpdb01";

-- Run Test01

-- Drop 3 DPBs
@drop_pdb "tstpdb01"
@drop_pdb "tstpdb02"
