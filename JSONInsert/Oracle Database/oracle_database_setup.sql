alter session set container=SB;

set serveroutput on size 1000000

declare
    e number;
begin
	select count(*) into e from DBA_TABLESPACES where TABLESPACE_NAME='SB';
	if e = 0 then
		execute immediate 'create tablespace SB datafile ''+DATA'' SIZE 2G AUTOEXTEND ON NEXT 1G MAXSIZE 16G';
	end if;

	select count(*) into e from DBA_USERS where USERNAME='SB';
	if e = 0 then
		execute immediate 'GRANT CREATE SESSION TO sb IDENTIFIED BY ${oci.datastore_password}';
		execute immediate 'ALTER USER sb DEFAULT TABLESPACE SB';
		execute immediate 'alter user sb quota unlimited on SB';
		execute immediate 'GRANT CREATE TABLE TO sb';
	end if;

	select count(*) into e from DBA_TABLES where TABLE_NAME='JSONINSERT' and OWNER='SB';
	if e = 0 then
		execute immediate 'CREATE TABLE sb.JSONINSERT (doc_id NUMBER(16), doc_time DATE, json_data VARCHAR2(2000)) tablespace SB';
	else
		execute immediate 'TRUNCATE TABLE sb.JSONINSERT REUSE STORAGE';
	end if;

end;

/
