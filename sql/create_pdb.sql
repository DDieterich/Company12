
--
-- Create PDB
--
-- Assumes connection to SYS@CDB$ROOT
--
-- Parameters
--   1 - Name of PDB
--

declare
   database_name   varchar2(128);
   users_datafile  varchar2(256);
   procedure run_stxt (in_stxt  in varchar2) is
   begin
      dbms_output.put_line(in_stxt || ';');
      execute immediate in_stxt;
   end run_stxt;
begin
   select name
    into  database_name
    from  v$database;
   select replace(min(file_name), database_name, database_name || '/&1.')
    into  users_datafile
    from  dba_data_files
    where tablespace_name = 'USERS';
   run_stxt('create pluggable database "&1."'                         || CHR(10) ||
          '  admin user "C12ADMIN" identified by "C12Admin_Password"' || CHR(10) ||
          '  default tablespace users datafile '''                    ||
             users_datafile || ''' size 5M autoextend on'             || CHR(10) ||
          '  FILE_NAME_CONVERT = (''pdbseed'', ''&1.'')'              || CHR(10) ||
          '  STORAGE UNLIMITED TEMPFILE REUSE');
end;
/

alter pluggable database "&1." open;

alter session set container = "&1.";
alter profile "DEFAULT" limit password_life_time unlimited;
alter session set container = "CDB$ROOT";
