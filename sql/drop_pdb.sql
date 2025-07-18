
--
-- Drop PDB
--
-- Assumes connection to SYS@CDB$ROOT
--
-- Parameters
--   1 - Name of PDB
--

alter pluggable database "&1." close immediate instances=all;

drop pluggable database "&1." including datafiles;

select name from v$services;
