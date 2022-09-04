/*
pythonist552 <at> gmail <dot> com
220828.1 = universal DDL script
*/
set linesize 2000
set serveroutput on
set verify off

declare
------------------------------------------------------------------------------------------------------------------------
-- Just only 2 parameters (V_TABLE_NAME, V_OLD_TABLE_NAMES) and 4 structures (V_TABLE_STRUCTURE, V_CONSTRAINTS, V_INDEXES, V_TRIGGERS) are required to be defined
------------------------------------------------------------------------------------------------------------------------
    V_TABLE_NAME            USER_TABLES.TABLE_NAME%type := 'PyTL_Interfaces_Records';
    -- if V_TABLE_NAME will be not found, but any table name from  V_OLD_TABLE_NAMES will be found,
    -- then the any one (couldn't predict which one) will be renamed into V_TABLE_NAME
    V_OLD_TABLE_NAMES       varchar2(4000 char)         := '';  -- '' or 'POSSIBLE_OLD_NAME' or 'POSSIBLE_OLD_NAME1,POSSIBLE_OLD_NAME2,POSSIBLE_OLD_NAME3'
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
    type T_FIELD_NAME       is record (                         -- desc ALL_TAB_COLUMNS;
        COLUMN_NAME         varchar2(256 char)
       ,DATA_TYPE           varchar2(256 char)
       ,DATA_CHAR_LENGTH    number
       ,CHAR_USED           varchar2(1 char)
       ,DATA_DEFAULT        varchar2(4000 char)                 -- it's LONG in the table ALL_TAB_COLUMNS
       ,OLD_COLUMN_NAMES    varchar2(4000 char)
    ); type T_TABLE_FIELDS  is table of T_FIELD_NAME;
    V_TABLE_STRUCTURE       T_TABLE_FIELDS := T_TABLE_FIELDS(
    --              COLUMN_NAME         DATA_TYPE       DATA_CHAR_LENGTH    CHAR_USED   DATA_DEFAULT                                    OLD_COLUMN_NAMES
        T_FIELD_NAME('UNIQUE_ID'        ,'NUMBER'       ,22                 ,''         ,''                                             ,'')
       ,T_FIELD_NAME('BATCH_ID'         ,'NUMBER'       ,22                 ,''         ,''                                             ,'')
       ,T_FIELD_NAME('INPUT_RECRD_UID' ,'VARCHAR2'     ,256                ,'C'        ,''                                             ,'')
       ,T_FIELD_NAME('OUTPUT_RECRD_UID' ,'VARCHAR2'     ,256                ,'C'        ,''                                             ,'')
       ,T_FIELD_NAME('INPUT_DATETIME'   ,'TIMESTAMP(6)' ,''                 ,''         ,''                                             ,'')
       ,T_FIELD_NAME('OUTPUT_DATETIME'  ,'TIMESTAMP(6)' ,''                 ,''         ,''                                             ,'')
       ,T_FIELD_NAME('LOCKED_BY'        ,'VARCHAR2'     ,256                ,'C'        ,''                                             ,'')
       ,T_FIELD_NAME('STATUS_CODE'      ,'NUMBER'       ,22                 ,''         ,''                                             ,'')
       ,T_FIELD_NAME('STATUS_DESC'      ,'VARCHAR2'     ,256                ,'C'        ,''                                             ,'')
       ,T_FIELD_NAME('STATUS_MSG'       ,'VARCHAR2'     ,4000               ,'C'        ,''                                             ,'')
       ,T_FIELD_NAME('IN_DATA'          ,'CLOB'         ,''                 ,''         ,''                                             ,'')
       ,T_FIELD_NAME('OUT_DATA'         ,'CLOB'         ,''                 ,''         ,''                                             ,'')
    );
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
    type T_CONSTRAINT       is record (
        CONSTRAINT_NAME     varchar2(256 char)
       ,CONSTRAINT_ACTION   varchar2(256 char)
       ,CONSTRAINT_CONDTN   varchar2(256 char)
       ,CONSTRAINT_REFCES   varchar2(256 char)
    ); type T_CONSTRAINTS   is table of T_CONSTRAINT;
    V_CONSTRAINTS           T_CONSTRAINTS := T_CONSTRAINTS(
    -- alter table V_TABLE_NAME add constraint V_FOUND_OBJECT_NAME primary key (CONSTRAINT_CONDTN)
    --               CONSTRAINT_NAME                    CONSTRAINT_ACTION   CONSTRAINT_CONDTN   CONSTRAINT_REFCES
        T_CONSTRAINT('PK'                               ,'primary key'      ,'UNIQUE_ID'        ,'')
    -- alter table V_TABLE_NAME add constraint V_FOUND_OBJECT_NAME foreign key (CONSTRAINT_CONDTN) references CONSTRAINT_REFCES
    --               CONSTRAINT_NAME                    CONSTRAINT_ACTION   CONSTRAINT_CONDTN   CONSTRAINT_REFCES
       ,T_CONSTRAINT('FK'                               ,'foreign key'      ,'BATCH_ID'         ,'PyTL_Interfaces_Batches(UNIQUE_ID)')
       ,T_CONSTRAINT('UNIQUE'                           ,'unique'           ,'OUTPUT_RECRD_UID' ,'')
    );
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
    type T_INDEX            is record (
        INDEX_NAME          varchar2(256 char)
       ,INDEX_UNIQUE        varchar2(256 char)
       ,INDEX_FIELDS        varchar2(256 char)
    ); type T_INDEXES       is table of T_INDEX;
    V_INDEXES               T_INDEXES := T_INDEXES(
    --              INDEX_NAME                          INDEX_UNIQUE        INDEX_FIELDS
       T_INDEX      ('BATCH_ID__OUTPUT_RECRD_UID'       ,''                 ,'BATCH_ID, OUTPUT_RECRD_UID')
    -- Not required: such index will be created automaticaly with primary key:
    -- ,T_INDEX     ('PK'                               ,'UNIQUE'           ,'UNIQUE_ID')
    );
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------
    -- Sequence+Trigger support:
    --      {V_TABLE_NAME}_{COLUMN_NAME}_SEQ will be created if it doesn't exist
    --      {V_TABLE_NAME}_{COLUMN_NAME}_TRG will be re-created to updated {COLUMN_NAME}
    type T_TRIGGER          is record (
        COLUMN_NAME         varchar2(256 char)
       ,TRIGGER_TYPE1       varchar2(256 char)
       ,TRIGGER_TYPE2       varchar2(256 char)
       ,TRIGGER_BODY        varchar2(256 char)
    ); type T_TRIGGERES     is table of T_TRIGGER;
    V_TRIGGERES             T_TRIGGERES := T_TRIGGERES(
    --              COLUMN_NAME     TRIGGER_TYPE1       TRIGGER_TYPE2   TRIGGER_BODY
    --  T_TRIGGER   ('UNIQUE_ID'    ,'BEFORE INSERT ON' ,'FOR EACH ROW' ,'begin select '||V_TABLE_NAME||'__{COLUMN_NAME}__SEQ.nextval into :new.{COLUMN_NAME} from dual; end;')
    );
------------------------------------------------------------------------------------------------------------------------
-- Go away. This is not a place to be. If you do try to enter here, you will fail and also be cursed.
-- If somehow you succeed, then do not complain that you entered unwarned, nor bother us with your deathbed prayers.
--                                                                      (c) Lord of Light by Roger Zelazny
------------------------------------------------------------------------------------------------------------------------
    V_TMP_TABLE_NAME        USER_TABLES.TABLE_NAME%type := 'TMP_STRUCTURE_TO_CREATE_UPDATE_TABLE';
    V_MAX_COLUMN_NAME       integer := -1;
    V_SQL_TEXT              varchar2(32000);

    V_FLAG_OBJECT_EXISTS    number;
    V_FOUND_OBJECT_NAME     varchar2(256);
begin
    dbms_output.put_line('***************************************************************************');
    dbms_output.put_line('******* Mission started.');
    --------------------------------------------------------------------------------------------------------------------
    -- Copy data from virtual table V_TABLE_STRUCTURE into real temporary table V_TMP_TABLE_NAME,
    -- because of it's impossible to compare virtual table of records (structure) with real table
    --------------------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    -- Drop temporary table V_TMP_TABLE_NAME if it exists
    ----------------------------------------------------------------------------
    select count(*) into V_FLAG_OBJECT_EXISTS from USER_TABLES where upper(TABLE_NAME) = upper(V_TMP_TABLE_NAME);
    if V_FLAG_OBJECT_EXISTS = 1 then
        ------------------------------------------------------------------------
        -- Drop already existed temporary table V_TMP_TABLE_NAME
        ------------------------------------------------------------------------
        dbms_output.put_line('*** Found already existed temporary table ' || V_TMP_TABLE_NAME || ', so drop it...');
        V_SQL_TEXT := 'drop table ' || V_TMP_TABLE_NAME;
        dbms_output.put_line('* ' || V_SQL_TEXT);
        execute immediate V_SQL_TEXT;
        dbms_output.put_line('*** Temporary table is droped successfully.');
    end if;
    ------------------------------------------------------------------------
    -- Create temporary table V_TMP_TABLE_NAME
    ------------------------------------------------------------------------
    dbms_output.put_line('*** Create temporary table ' ||  V_TMP_TABLE_NAME || '...');
    V_SQL_TEXT := 'create table ' || V_TMP_TABLE_NAME || ' (
        COLUMN_NAME         varchar2(256 char)
       ,DATA_TYPE           varchar2(256 char)
       ,DATA_CHAR_LENGTH    number
       ,CHAR_USED           varchar2(1 char)
       ,DATA_DEFAULT        varchar2(4000 char)
       ,OLD_COLUMN_NAMES    varchar2(4000 char)
    )';
    -- dbms_output.put_line('* ' || V_SQL_TEXT);
    execute immediate V_SQL_TEXT;
    dbms_output.put_line('*** Temporary table is created successfully.');
    ------------------------------------------------------------------------
    -- Copy data from virtual table V_TABLE_STRUCTURE into real temporary table V_TMP_TABLE_NAME
    ------------------------------------------------------------------------
    dbms_output.put_line('*** Copy data from virtual table V_TABLE_STRUCTURE into real temporary table ' ||  V_TMP_TABLE_NAME || '...');
    for i in 1 .. V_TABLE_STRUCTURE.count loop
        V_SQL_TEXT := 'insert into '|| V_TMP_TABLE_NAME ||'(COLUMN_NAME, DATA_TYPE, DATA_CHAR_LENGTH, CHAR_USED, DATA_DEFAULT, OLD_COLUMN_NAMES)'
                      || ' values('
                      || '''' || upper(V_TABLE_STRUCTURE(i).COLUMN_NAME) || ''''
                      || ', '
                      || '''' || upper(V_TABLE_STRUCTURE(i).DATA_TYPE) || ''''
                      || ', '
                      || case when V_TABLE_STRUCTURE(i).DATA_CHAR_LENGTH is null then 0 else V_TABLE_STRUCTURE(i).DATA_CHAR_LENGTH end
                      || ', '
                      || '''' || upper(V_TABLE_STRUCTURE(i).CHAR_USED) || ''''
                      || ', '
                      || '''' || replace(V_TABLE_STRUCTURE(i).DATA_DEFAULT, '''', '''''') || ''''
                      || ', '
                      || '''' || case when V_TABLE_STRUCTURE(i).OLD_COLUMN_NAMES is null then '' else V_TABLE_STRUCTURE(i).OLD_COLUMN_NAMES end || ''''
                      || ')'
        ;
        -- dbms_output.put_line('* ' || V_SQL_TEXT);
        execute immediate V_SQL_TEXT;
        -- dbms_output.put_line('*** Inserted successfully.');
    end loop;
    dbms_output.put_line('*** Copied successfully.');

    --------------------------------------------------------------------------------------------------------------------
    -- Rename from V_OLD_TABLE_NAMES into TABLE_NAME or create TABLE_NAME
    --------------------------------------------------------------------------------------------------------------------
    select count(*) into V_FLAG_OBJECT_EXISTS from USER_TABLES where upper(TABLE_NAME) = upper(V_TABLE_NAME);
    if V_FLAG_OBJECT_EXISTS = 0 then
        ------------------------------------------------------------------------
        -- Table V_TABLE_NAME doesn't exist
        ------------------------------------------------------------------------
        dbms_output.put_line('*** Table ' || V_TABLE_NAME || ' is NOT found...');
        if V_OLD_TABLE_NAMES is not null then
            select count(*) into V_FLAG_OBJECT_EXISTS from USER_TABLES where
                TABLE_NAME in (
                    select upper(trim(regexp_substr(V_OLD_TABLE_NAMES, '[^,]+', 1, level)))
                    from dual connect by regexp_substr(V_OLD_TABLE_NAMES, '[^,]+', 1, level) is not null
                )
            ;
            if V_FLAG_OBJECT_EXISTS = 1 then
                ------------------------------------------------------------------------
                -- Rename if one of V_OLD_TABLE_NAMES is found
                ------------------------------------------------------------------------
                select TABLE_NAME into V_FOUND_OBJECT_NAME from USER_TABLES where
                    TABLE_NAME in (
                        select upper(trim(regexp_substr(V_OLD_TABLE_NAMES, '[^,]+', 1, level)))
                        from dual connect by regexp_substr(V_OLD_TABLE_NAMES, '[^,]+', 1, level) is not null
                    )
                    and rownum = 1
                ;
                dbms_output.put_line('*** Old table ' || V_FOUND_OBJECT_NAME || ' is FOUND, so rename it into new one...');
                V_SQL_TEXT := 'rename ' || V_FOUND_OBJECT_NAME || ' to ' || V_TABLE_NAME;
                dbms_output.put_line('* ' || V_SQL_TEXT);
                execute immediate V_SQL_TEXT;
                dbms_output.put_line('*** Renamed successfully.');
            else
                dbms_output.put_line('*** No one table from [' || V_OLD_TABLE_NAMES || '] is NOT found...');
            end if; -- Check if OLD table exists
        end if; -- if V_OLD_TABLE_NAMES is not null then
        ------------------------------------------------------------------------
        -- Check more one time, possible old table from V_OLD_TABLE_NAMES is found and renamed into V_TABLE_NAME
        ------------------------------------------------------------------------
        select count(*) into V_FLAG_OBJECT_EXISTS from USER_TABLES where upper(TABLE_NAME) = upper(V_TABLE_NAME);
        if V_FLAG_OBJECT_EXISTS = 0 then
            dbms_output.put_line('*** Table ' || V_TABLE_NAME || ' is NOT found again, so create the new one...');
            ------------------------------------------------------------------------
            -- Create table
            ------------------------------------------------------------------------
            V_SQL_TEXT := 'create table ' || V_TABLE_NAME || '(' || chr(10);
            -- get max length of field names
            for i in 1 .. V_TABLE_STRUCTURE.count loop
                V_MAX_COLUMN_NAME := greatest(V_MAX_COLUMN_NAME, length(V_TABLE_STRUCTURE(i).COLUMN_NAME));
            end loop;
            -- generate sql for execute immediate
            for i in 1 .. V_TABLE_STRUCTURE.count loop
                if i > 1 then
                    V_SQL_TEXT :=  V_SQL_TEXT || ',' || chr(10);
                end if;
                V_SQL_TEXT := V_SQL_TEXT || '    '
                    || RPAD( V_TABLE_STRUCTURE(i).COLUMN_NAME, V_MAX_COLUMN_NAME+1, ' ')
                    || V_TABLE_STRUCTURE(i).DATA_TYPE
                    || case when V_TABLE_STRUCTURE(i).DATA_CHAR_LENGTH is not null then
                            '(' || V_TABLE_STRUCTURE(i).DATA_CHAR_LENGTH ||
                                case
                                    when upper(V_TABLE_STRUCTURE(i).CHAR_USED) = 'B' then ' BYTE'
                                    when upper(V_TABLE_STRUCTURE(i).CHAR_USED) = 'C' then ' CHAR'
                                    else ''
                                end
                            || ')'
                            else ''
                       end
                    || case when V_TABLE_STRUCTURE(i).DATA_DEFAULT is not null then
                            ' default ' || V_TABLE_STRUCTURE(i).DATA_DEFAULT
                            else ''
                       end
                ;
            end loop;
            V_SQL_TEXT := V_SQL_TEXT ||  chr(10) || ')';
            dbms_output.put_line('* ' || V_SQL_TEXT);
            execute immediate V_SQL_TEXT;
            dbms_output.put_line('*** Created successfully.');

        else
            dbms_output.put_line('*** Old table ' || V_FOUND_OBJECT_NAME || ' is FOUND and successfully renamed into ' || V_TABLE_NAME || '...');
        end if; -- Double check if table was not renamed from the old one
    else
        dbms_output.put_line('*** Table ' || V_TABLE_NAME || ' is FOUND...');
    end if; -- Check if table not exists

    -- *****************************************************************************************************************
    -- https://community.oracle.com/tech/developers/discussion/3649885/execute-immediate-for-select-with-loop
    -- Because of V_TMP_TABLE_NAME doesn't exist at the moment of script start, Oracle checks used tables
    -- and prevent running of script with not existed table. Only code incapsulated into 'execute immediate' is possible to run.
    -- *****************************************************************************************************************
    --------------------------------------------------------------------------------------------------------------------
    -- COLUMN_NAME exists in meta-structure (V_TMP_TABLE_NAME), but not exists in REAL (ALL_TAB_COLUMNS)
    -- but one of OLD_COLUMN_NAMES exists in REAL (ALL_TAB_COLUMNS) => rename
    --------------------------------------------------------------------------------------------------------------------
    execute immediate q'{
declare
    V_SQL_TEXT varchar2(32000);
begin
    for COLUMNS_TO_RENAME in (
        select t6.COLUMN_NAME as EXISTED_NAME, t5.NEW_NAME
        from
            (
                select trim(regexp_substr(t4.OLD_COLUMN_NAMES, '[^,]+', 1, level)) as OLD_NAME, t4.COLUMN_NAME as NEW_NAME
                from (
                    select t3.OLD_COLUMN_NAMES, t3.COLUMN_NAME from }' || V_TMP_TABLE_NAME || q'{ t3 where t3.COLUMN_NAME in (
                        select t1.COLUMN_NAME from }' || V_TMP_TABLE_NAME || q'{ t1
                        left outer join (select * from ALL_TAB_COLUMNS where upper(TABLE_NAME) = '}' || upper(V_TABLE_NAME) || q'{') t2 on t1.COLUMN_NAME = t2.COLUMN_NAME
                        where t2.DATA_TYPE is null
                    )
                    and t3.OLD_COLUMN_NAMES is not null
                ) t4
                connect by regexp_substr(t4.OLD_COLUMN_NAMES, '[^,]+', 1, level) is not null
            ) t5
        join (select * from ALL_TAB_COLUMNS where upper(TABLE_NAME) = '}' || upper(V_TABLE_NAME) || q'{') t6 on t6.COLUMN_NAME = t5.OLD_NAME
    )
    loop
        dbms_output.put_line('[*] ' || COLUMNS_TO_RENAME.EXISTED_NAME || ' -> ' || COLUMNS_TO_RENAME.NEW_NAME);
        V_SQL_TEXT := 'alter table }' || V_TABLE_NAME || q'{ rename column ' || COLUMNS_TO_RENAME.EXISTED_NAME || ' to ' || COLUMNS_TO_RENAME.NEW_NAME;
        dbms_output.put_line('* ' || V_SQL_TEXT);
        execute immediate V_SQL_TEXT;
        dbms_output.put_line('*** Column is renamed successfully.');
    end loop;
end; }';

    --------------------------------------------------------------------------------------------------------------------
    -- COLUMN_NAME exists in meta-structure (V_TMP_TABLE_NAME), but not exist in REAL (ALL_TAB_COLUMNS) => add column
    --------------------------------------------------------------------------------------------------------------------
    execute immediate q'{
declare
    V_SQL_TEXT varchar2(32000);
begin
    for COLUMNS_TO_ADD in (
        select t1.* from }' || V_TMP_TABLE_NAME || q'{ t1
        left outer join (select * from ALL_TAB_COLUMNS where upper(TABLE_NAME) = '}' || upper(V_TABLE_NAME) || q'{') t2 on t1.COLUMN_NAME = t2.COLUMN_NAME
        where t2.DATA_TYPE is null
    )
    loop
        dbms_output.put_line('[+] ' || COLUMNS_TO_ADD.COLUMN_NAME);
        V_SQL_TEXT := 'alter table }' || V_TABLE_NAME || q'{ add '
                    || COLUMNS_TO_ADD.COLUMN_NAME
                    || ' '
                    || COLUMNS_TO_ADD.DATA_TYPE
                    || case when COLUMNS_TO_ADD.DATA_CHAR_LENGTH is not null then
                            '(' || COLUMNS_TO_ADD.DATA_CHAR_LENGTH ||
                                case
                                    when upper(COLUMNS_TO_ADD.CHAR_USED) = 'B' then ' BYTE'
                                    when upper(COLUMNS_TO_ADD.CHAR_USED) = 'C' then ' CHAR'
                                    else ''
                                end
                            || ')'
                            else ''
                       end
                    || case when COLUMNS_TO_ADD.DATA_DEFAULT is not null then
                            ' default ' || COLUMNS_TO_ADD.DATA_DEFAULT
                            else ''
                       end
        ;
        dbms_output.put_line('* ' || V_SQL_TEXT);
        execute immediate V_SQL_TEXT;
        dbms_output.put_line('*** Column is added successfully.');
    end loop;
end; }';
    --------------------------------------------------------------------------------------------------------------------
    -- COLUMN_NAME exists in REAL (ALL_TAB_COLUMNS), but not exist in meta-structure (V_TMP_TABLE_NAME) => drop column
    --------------------------------------------------------------------------------------------------------------------
    execute immediate q'{
declare
    V_SQL_TEXT varchar2(32000);
begin
    for COLUMNS_TO_DROP in (
        select t2.COLUMN_NAME from }' || V_TMP_TABLE_NAME || q'{ t1
        right outer join (select * from ALL_TAB_COLUMNS where upper(TABLE_NAME) = '}' || upper(V_TABLE_NAME) || q'{') t2 on t1.COLUMN_NAME = t2.COLUMN_NAME
        where t1.DATA_TYPE is null
    )
    loop
        dbms_output.put_line('[-] ' || COLUMNS_TO_DROP.COLUMN_NAME);
        V_SQL_TEXT := 'alter table }' || V_TABLE_NAME || q'{ drop column ' || COLUMNS_TO_DROP.COLUMN_NAME;
        dbms_output.put_line('* ' || V_SQL_TEXT);
        execute immediate V_SQL_TEXT;
        dbms_output.put_line('*** Column is droped successfully.');
    end loop;
end; }';

    --------------------------------------------------------------------------------------------------------------------
    -- COLUMN_NAME exists in both: in REAL (ALL_TAB_COLUMNS) and in meta-structure (V_TMP_TABLE_NAME)
    -- but has DIFFERENT types, except DATA_DEFAULT (it's LONG in ALL_TAB_COLUMNS, so it's not possible to compare by ordinary way)
    --------------------------------------------------------------------------------------------------------------------
    execute immediate q'{
declare
    V_SQL_TEXT varchar2(32000);
begin
    for COLUMNS_TO_MODIFY in (
        select
            t1.*,
            t2.DATA_TYPE        as CURRENT_DATA_TYPE,
            t2.DATA_LENGTH      as CURRENT_DATA_LENGTH,
            t2.CHAR_LENGTH      as CURRENT_CHAR_LENGTH,
            t2.CHAR_USED        as CURRENT_CHAR_USED
        from }' || V_TMP_TABLE_NAME || q'{ t1
        left outer join (select * from ALL_TAB_COLUMNS where upper(TABLE_NAME) = '}' || upper(V_TABLE_NAME) || q'{') t2 on t1.COLUMN_NAME = t2.COLUMN_NAME
        where
            t2.COLUMN_NAME is not null
            and (
                   t1.DATA_TYPE  <> t2.DATA_TYPE
                or t1.CHAR_USED  <> t2.CHAR_USED
                or ( t1.CHAR_USED is null       and t1.DATA_CHAR_LENGTH <> 0 and t1.DATA_CHAR_LENGTH <> t2.DATA_LENGTH)
                or ( t1.CHAR_USED is not null   and t1.DATA_CHAR_LENGTH <> 0 and t1.DATA_CHAR_LENGTH <> t2.CHAR_LENGTH)
            )
    )
    loop
        dbms_output.put_line('[^] ' || COLUMNS_TO_MODIFY.COLUMN_NAME);
        if COLUMNS_TO_MODIFY.CURRENT_DATA_TYPE <> COLUMNS_TO_MODIFY.DATA_TYPE then
            dbms_output.put_line('[^]     ' || ' DATA_TYPE   from ''' || COLUMNS_TO_MODIFY.CURRENT_DATA_TYPE   || ''' into ''' || COLUMNS_TO_MODIFY.DATA_TYPE   || '''');
        end if;
        if COLUMNS_TO_MODIFY.CHAR_USED is null then
            if COLUMNS_TO_MODIFY.CURRENT_DATA_LENGTH <> COLUMNS_TO_MODIFY.DATA_CHAR_LENGTH then
                dbms_output.put_line('[^]     ' || ' DATA_LENGTH from ''' || COLUMNS_TO_MODIFY.CURRENT_DATA_LENGTH || ''' into ''' || COLUMNS_TO_MODIFY.DATA_CHAR_LENGTH || '''');
            end if;
        else
            if COLUMNS_TO_MODIFY.CURRENT_CHAR_LENGTH <> COLUMNS_TO_MODIFY.DATA_CHAR_LENGTH then
                dbms_output.put_line('[^]     ' || ' CHAR_LENGTH from ''' || COLUMNS_TO_MODIFY.CURRENT_CHAR_LENGTH || ''' into ''' || COLUMNS_TO_MODIFY.DATA_CHAR_LENGTH || '''');
            end if;
        end if;
        if COLUMNS_TO_MODIFY.CURRENT_CHAR_USED <> COLUMNS_TO_MODIFY.CHAR_USED then
            dbms_output.put_line('[^]     ' || ' CHAR_USED   from ''' || COLUMNS_TO_MODIFY.CURRENT_CHAR_USED   || ''' into ''' || COLUMNS_TO_MODIFY.CHAR_USED   || '''');
        end if;
        V_SQL_TEXT := 'alter table }' || V_TABLE_NAME || q'{ modify '
                    || COLUMNS_TO_MODIFY.COLUMN_NAME
                    || ' '
                    || COLUMNS_TO_MODIFY.DATA_TYPE
                    || case when COLUMNS_TO_MODIFY.DATA_CHAR_LENGTH is not null then
                            '(' || COLUMNS_TO_MODIFY.DATA_CHAR_LENGTH ||
                                case
                                    when upper(COLUMNS_TO_MODIFY.CHAR_USED) = 'B' then ' BYTE'
                                    when upper(COLUMNS_TO_MODIFY.CHAR_USED) = 'C' then ' CHAR'
                                    else ''
                                end
                            || ')'
                            else ''
                       end
                    || case when COLUMNS_TO_MODIFY.DATA_DEFAULT is not null then
                            ' default ' || COLUMNS_TO_MODIFY.DATA_DEFAULT
                            else ''
                       end
        ;
        dbms_output.put_line('* ' || V_SQL_TEXT);
        execute immediate V_SQL_TEXT;
        dbms_output.put_line('*** Column type is modified successfully.');
    end loop;
end; }';

    --------------------------------------------------------------------------------------------------------------------
    -- COLUMN_NAME exists in both: in REAL (ALL_TAB_COLUMNS) and in meta-structure (V_TMP_TABLE_NAME)
    -- but has DIFFERENT values in DATA_DEFAULT (it's LONG in ALL_TAB_COLUMNS, so it's not possible to compare by ordinary way)
    --------------------------------------------------------------------------------------------------------------------
    execute immediate q'{
declare
    V_SQL_TEXT          varchar2(32000);
    v_DATA_DEFAULT_ASIS varchar2(4000 char);
begin
    for LONG_COLUMNS_TO_MODIFY in (
        select t1.*, t2.DATA_DEFAULT as ASIS from }' || V_TMP_TABLE_NAME || q'{ t1
        right outer join (select * from ALL_TAB_COLUMNS where upper(TABLE_NAME) = '}' || upper(V_TABLE_NAME) || q'{' and DATA_DEFAULT is not null) t2 on t1.COLUMN_NAME = t2.COLUMN_NAME
    )
    loop
        v_DATA_DEFAULT_ASIS := LONG_COLUMNS_TO_MODIFY.ASIS;           -- because of impossible to compare LONG by other way
        if v_DATA_DEFAULT_ASIS <> LONG_COLUMNS_TO_MODIFY.DATA_DEFAULT then
            dbms_output.put_line('[^^] ' || LONG_COLUMNS_TO_MODIFY.COLUMN_NAME);
            V_SQL_TEXT := 'alter table }' || V_TABLE_NAME || q'{ modify '
                        || LONG_COLUMNS_TO_MODIFY.COLUMN_NAME
                        || ' '
                        || LONG_COLUMNS_TO_MODIFY.DATA_TYPE
                        || case when LONG_COLUMNS_TO_MODIFY.DATA_CHAR_LENGTH is not null then
                                '(' || LONG_COLUMNS_TO_MODIFY.DATA_CHAR_LENGTH ||
                                    case
                                        when upper(LONG_COLUMNS_TO_MODIFY.CHAR_USED) = 'B' then ' BYTE'
                                        when upper(LONG_COLUMNS_TO_MODIFY.CHAR_USED) = 'C' then ' CHAR'
                                        else ''
                                    end
                                || ')'
                                else ''
                           end
                        || case when LONG_COLUMNS_TO_MODIFY.DATA_DEFAULT is not null then
                                ' default ' || LONG_COLUMNS_TO_MODIFY.DATA_DEFAULT
                                else ''
                           end
            ;
            dbms_output.put_line('* ' || V_SQL_TEXT);
            execute immediate V_SQL_TEXT;
            dbms_output.put_line('*** Column default data is modified successfully.');
        end if;
    end loop;
end; }';

    --------------------------------------------------------------------------------------------------------------------
    -- Add not existed sequences, re-create triggers
    --------------------------------------------------------------------------------------------------------------------
    dbms_output.put_line('*** Add not existed sequences, re-create triggers...');
    for i in 1 .. V_TRIGGERES.count loop
        V_FOUND_OBJECT_NAME := upper(V_TABLE_NAME || '__' || V_TRIGGERES(i).COLUMN_NAME  || '__SEQ');

        select count(*) into V_FLAG_OBJECT_EXISTS
        from ALL_SEQUENCES t1
        where
            upper(t1.SEQUENCE_NAME) = V_FOUND_OBJECT_NAME
        ;
        if V_FLAG_OBJECT_EXISTS <> 1 then
            ------------------------------------------------------------------------
            -- Create new sequence V_FOUND_OBJECT_NAME if it doesn't exist
            ------------------------------------------------------------------------
            dbms_output.put_line('*** Add sequence ' || V_FOUND_OBJECT_NAME || ' ...');
            V_SQL_TEXT :=  'create sequence ' || V_FOUND_OBJECT_NAME || ' increment by 1 start with 1 nomaxvalue nocycle cache 10';
            dbms_output.put_line('* ' || V_SQL_TEXT);
            execute immediate V_SQL_TEXT;
            dbms_output.put_line('*** Sequence ' || V_FOUND_OBJECT_NAME || ' is created successfully.');
        else
            dbms_output.put_line('*** Existed sequence ' || V_FOUND_OBJECT_NAME || ' is FOUND. Nothing will be done.');
        end if;

        ------------------------------------------------------------------------
        -- Re-create trigger V_FOUND_OBJECT_NAME
        ------------------------------------------------------------------------
        V_FOUND_OBJECT_NAME := upper(V_TABLE_NAME || '__' || V_TRIGGERES(i).COLUMN_NAME  || '__TRG');
        dbms_output.put_line('*** Re-create trigger ' || V_FOUND_OBJECT_NAME || ' ...');
        V_SQL_TEXT :=  'create or replace trigger ' || V_FOUND_OBJECT_NAME || ' ' || V_TRIGGERES(i).TRIGGER_TYPE1
                       || ' ' || V_TABLE_NAME || ' ' || V_TRIGGERES(i).TRIGGER_TYPE2 || ' '
                       || replace(V_TRIGGERES(i).TRIGGER_BODY, '{COLUMN_NAME}', V_TRIGGERES(i).COLUMN_NAME);
        dbms_output.put_line('* ' || V_SQL_TEXT);
        execute immediate V_SQL_TEXT;
        dbms_output.put_line('*** Trigger ' || V_FOUND_OBJECT_NAME || ' is re-created successfully.');
    end loop;

    --------------------------------------------------------------------------------------------------------------------
    -- Drop/add constraints
    --------------------------------------------------------------------------------------------------------------------
    dbms_output.put_line('*** Drop/add constraints...');
    for i in 1 .. V_CONSTRAINTS.count loop
        V_FOUND_OBJECT_NAME := upper(V_TABLE_NAME || '__' || V_CONSTRAINTS(i).CONSTRAINT_NAME);

        select count(*) into V_FLAG_OBJECT_EXISTS
        from ALL_CONSTRAINTS t1
        where
            upper(t1.TABLE_NAME) = upper(V_TABLE_NAME)
            and upper(t1.CONSTRAINT_NAME) = V_FOUND_OBJECT_NAME
        ;
        if V_FLAG_OBJECT_EXISTS = 1 then
            ------------------------------------------------------------------------
            -- Drop already existed V_FOUND_OBJECT_NAME
            ------------------------------------------------------------------------
            dbms_output.put_line('*** Found already existed constraint ' || V_FOUND_OBJECT_NAME || ', so drop it...');
            V_SQL_TEXT := 'alter table ' || V_TABLE_NAME || ' drop constraint ' || V_FOUND_OBJECT_NAME || ' cascade';
            dbms_output.put_line('* ' || V_SQL_TEXT);
            execute immediate V_SQL_TEXT;
            dbms_output.put_line('*** Constraint ' || V_FOUND_OBJECT_NAME || ' is droped successfully.');
        end if;

        dbms_output.put_line('*** Add constraint ' || V_FOUND_OBJECT_NAME || ' ...');
        V_SQL_TEXT :=  'alter table '|| upper(V_TABLE_NAME) || ' add constraint ' || V_FOUND_OBJECT_NAME
                       || ' ' || V_CONSTRAINTS(i).CONSTRAINT_ACTION || ' (' || V_CONSTRAINTS(i).CONSTRAINT_CONDTN || ')'
        ;
        if V_CONSTRAINTS(i).CONSTRAINT_REFCES is not null then
            V_SQL_TEXT :=  V_SQL_TEXT || ' references ' || V_CONSTRAINTS(i).CONSTRAINT_REFCES;
        end if;

        dbms_output.put_line('* ' || V_SQL_TEXT);
        execute immediate V_SQL_TEXT;
        dbms_output.put_line('*** Constraint ' || V_FOUND_OBJECT_NAME || ' is created successfully.');
    end loop;

    --------------------------------------------------------------------------------------------------------------------
    -- Drop/add indexes
    --------------------------------------------------------------------------------------------------------------------
    dbms_output.put_line('*** Drop/add indexes...');
    for i in 1 .. V_INDEXES.count loop
        V_FOUND_OBJECT_NAME := upper(V_TABLE_NAME || '__' || V_INDEXES(i).INDEX_NAME);

        select count(*) into V_FLAG_OBJECT_EXISTS
        from ALL_INDEXES t1
        where
            upper(t1.TABLE_NAME) = upper(V_TABLE_NAME)
            and upper(t1.INDEX_NAME) = V_FOUND_OBJECT_NAME
        ;
        if V_FLAG_OBJECT_EXISTS = 1 then
            ------------------------------------------------------------------------
            -- Drop already existed V_FOUND_OBJECT_NAME
            ------------------------------------------------------------------------
            dbms_output.put_line('*** Found already existed index ' || V_FOUND_OBJECT_NAME || ', so drop it...');
            V_SQL_TEXT := 'drop index ' || V_FOUND_OBJECT_NAME;
            dbms_output.put_line('* ' || V_SQL_TEXT);
            execute immediate V_SQL_TEXT;
            dbms_output.put_line('*** Index ' || V_FOUND_OBJECT_NAME || ' is droped successfully.');
        end if;

        dbms_output.put_line('*** Add index ' || V_FOUND_OBJECT_NAME || ' ...');
        V_SQL_TEXT :=  'create ' || V_INDEXES(i).INDEX_UNIQUE || ' index ' || V_FOUND_OBJECT_NAME
                       || ' on '|| upper(V_TABLE_NAME) || ' (' || V_INDEXES(i).INDEX_FIELDS || ')';
        dbms_output.put_line('* ' || V_SQL_TEXT);
        execute immediate V_SQL_TEXT;
        dbms_output.put_line('*** Index ' || V_FOUND_OBJECT_NAME || ' is created successfully.');
    end loop;

    --------------------------------------------------------------------------------------------------------------------
    -- Drop temporary table V_TMP_TABLE_NAME
    --------------------------------------------------------------------------------------------------------------------
    dbms_output.put_line('*** Drop temporary table ' || V_TMP_TABLE_NAME || '...');
    V_SQL_TEXT := 'drop table ' || V_TMP_TABLE_NAME;
    dbms_output.put_line('* ' || V_SQL_TEXT);
    execute immediate V_SQL_TEXT;
    dbms_output.put_line('*** Temporary table is droped successfully.');

    commit;
    dbms_output.put_line('******* Mission acomplished.');
    dbms_output.put_line('***************************************************************************');
end;
/
exit;
