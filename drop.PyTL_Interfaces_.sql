/*
pythonist552 <at> gmail <dot> com
220904.1 = universal script for tables/packages dropping
*/
set linesize 2000
set serveroutput on
set verify off

declare
    type LIST_OF_STR        is table of varchar2(256);
    V_TABLE_NAMES_TO_DROP   LIST_OF_STR := LIST_OF_STR(
        'PyTL_Sequences'
       ,'PyTL_Interfaces_Records'
       ,'PyTL_Interfaces_Batches'
    );
    V_PACKAGE_NAMES_TO_DROP LIST_OF_STR := LIST_OF_STR(
        'PyTL_Interfaces_Utils'
    );
begin
    for i in 1 .. V_TABLE_NAMES_TO_DROP.count loop
        dbms_output.put_line('*** Try to find table ' || V_TABLE_NAMES_TO_DROP(i) || ' and linked sequences.');
        
        for SEQUENCE_TO_DROP in (
            select * from ALL_SEQUENCES where upper(SEQUENCE_NAME) like upper(V_TABLE_NAMES_TO_DROP(i) || '__%')
        ) loop
            dbms_output.put_line('** Sequence is found, so drop sequence ' || SEQUENCE_TO_DROP.SEQUENCE_NAME);
            execute immediate 'drop sequence ' || SEQUENCE_TO_DROP.SEQUENCE_NAME;
        end loop;
        
        for TABLE_TO_DROP in (
            select * from USER_TABLES where upper(TABLE_NAME) like upper(V_TABLE_NAMES_TO_DROP(i))
        ) loop
            dbms_output.put_line('** Table is found, so drop table ' || TABLE_TO_DROP.TABLE_NAME || ' and linked constraints, indexes, triggers, ');
            execute immediate 'drop table ' || TABLE_TO_DROP.TABLE_NAME || ' cascade constraints';
        end loop;
    end loop;
    
    for i in 1 .. V_PACKAGE_NAMES_TO_DROP.count loop
        dbms_output.put_line('*** Try to find package ' || V_PACKAGE_NAMES_TO_DROP(i));
        
        for PACKAGE_TO_DROP in (
            select * from ALL_OBJECTS where OBJECT_TYPE = 'PACKAGE' and upper(OBJECT_NAME) like upper(V_PACKAGE_NAMES_TO_DROP(i))
        ) loop
            dbms_output.put_line('** Package is found, so drop package ' || PACKAGE_TO_DROP.OBJECT_NAME);
            execute immediate 'drop package ' || PACKAGE_TO_DROP.OBJECT_NAME;
        end loop;
    end loop;
end;
/
exit;
