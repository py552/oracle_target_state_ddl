/*
pythonist552 <at> gmail <dot> com
220904.1 = support utilities
*/
create or replace package PyTL_Interfaces_Utils is

    procedure save_sequence_value(p_sequence_name varchar2, p_sequence_value number);
    function get_sequence_value(P_SEQUENCE_NAME varchar2, P_SEQUENCE_RESERVE number default 1) return number;

    type T_PYTL_INTERFACES_BATCHES_TABLE is table of PyTL_Interfaces_Batches%ROWTYPE;
    function get_and_lock_pytl_interfaces_batches(OUTPUT_BATCH_UID_LIST varchar2, LOCK_BY varchar2) return T_PYTL_INTERFACES_BATCHES_TABLE pipelined;
    procedure unlock_pytl_interfaces_batches(UNLOCK_LOCKED_BY varchar2);

    type T_PYTL_INTERFACES_RECORDS_TABLE is table of PyTL_Interfaces_Records%ROWTYPE;
    function get_and_lock_pytl_interfaces_records(OUTPUT_RECRD_UID_LIST varchar2, LOCK_BY varchar2) return T_PYTL_INTERFACES_RECORDS_TABLE pipelined;
    procedure unlock_pytl_interfaces_records(UNLOCK_LOCKED_BY varchar2);

end PyTL_Interfaces_Utils;
/
commit;
/
create or replace package body PyTL_Interfaces_Utils is
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
    procedure save_sequence_value(P_SEQUENCE_NAME varchar2, P_SEQUENCE_VALUE number)
    as
        pragma autonomous_transaction;
    begin
        merge into PyTL_Sequences using dual on (SEQUENCE_NAME = P_SEQUENCE_NAME)
        when not matched then insert (SEQUENCE_NAME, SEQUENCE_VALUE) values (P_SEQUENCE_NAME, P_SEQUENCE_VALUE)
        when matched then update set SEQUENCE_VALUE = P_SEQUENCE_VALUE;

        commit;
        return;
    end save_sequence_value;
--------------------------------------------------------------------------------
    function get_sequence_value(P_SEQUENCE_NAME varchar2, P_SEQUENCE_RESERVE number default 1) return number
    as
        V_SEQUENCE_VALUE    number;
    begin
        select sum(SEQUENCE_VALUE)
        into   V_SEQUENCE_VALUE
        from   PyTL_Sequences
        where  upper(SEQUENCE_NAME) = upper(P_SEQUENCE_NAME)
        ;

        if V_SEQUENCE_VALUE is null then
            V_SEQUENCE_VALUE := 0;
        end if;

        PyTL_Interfaces_Utils.save_sequence_value(P_SEQUENCE_NAME, V_SEQUENCE_VALUE + P_SEQUENCE_RESERVE);
        return V_SEQUENCE_VALUE;
    end get_sequence_value;
--------------------------------------------------------------------------------
    function get_and_lock_pytl_interfaces_batches(OUTPUT_BATCH_UID_LIST varchar2, LOCK_BY varchar2) return T_PYTL_INTERFACES_BATCHES_TABLE pipelined
    as
        pragma autonomous_transaction;
        PYTL_INTERFACES_BATCHES_COLLECTION T_PYTL_INTERFACES_BATCHES_TABLE;
    begin
/*
ORA-01002: fetch out of sequence
*Cause:    This error means that a fetch has been attempted from a cursor
           which is no longer valid.  Note that a PL/SQL cursor loop
           implicitly does fetches, and thus may also cause this error.
           There are a number of possible causes for this error, including:
           1) Fetching from a cursor after the last row has been retrieved
           and the ORA-1403 error returned.
           2) If the cursor has been opened with the FOR UPDATE clause,
           fetching after a COMMIT has been issued will return the error.
           3) Rebinding any placeholders in the SQL statement, then issuing
           a fetch before reexecuting the statement.
*Action:   1) Do not issue a fetch statement after the last row has been
           retrieved - there are no more rows to fetch.
           2) Do not issue a COMMIT inside a fetch loop for a cursor
           that has been opened FOR UPDATE.
           3) Reexecute the statement after rebinding, then attempt to
           fetch again.

update+commit and pipe are not allowed inside the same loop
with cursor 'select ... for update nowait'+'... where current of ROW_CURSOR',
so lets split into the 2 loops: 1) update 2) return row
*/
        select *
        bulk collect into PYTL_INTERFACES_BATCHES_COLLECTION
        from PyTL_Interfaces_Batches
        where
            LOCKED_BY is null
            and OUTPUT_BATCH_UID in (
                    select regexp_substr(OUTPUT_BATCH_UID_LIST, '[^,]+', 1, level) from dual
                    connect by level <= length(regexp_replace(OUTPUT_BATCH_UID_LIST, '[^,]+')) + 1
            )
        for update of LOCKED_BY skip locked;

        if PYTL_INTERFACES_BATCHES_COLLECTION.count > 0 then
            for i in PYTL_INTERFACES_BATCHES_COLLECTION.first .. PYTL_INTERFACES_BATCHES_COLLECTION.last
            loop
                update PyTL_Interfaces_Records
                set LOCKED_BY = LOCK_BY
                where UNIQUE_ID = PYTL_INTERFACES_BATCHES_COLLECTION(i).UNIQUE_ID;
            end loop;
            commit;

            for i in PYTL_INTERFACES_BATCHES_COLLECTION.first .. PYTL_INTERFACES_BATCHES_COLLECTION.last
            loop
                pipe row (PYTL_INTERFACES_BATCHES_COLLECTION(i));
            end loop;
        else
            rollback;
        end if;

        return;
    end get_and_lock_pytl_interfaces_batches;
--------------------------------------------------------------------------------
    procedure unlock_pytl_interfaces_batches(UNLOCK_LOCKED_BY varchar2)
    as
        pragma autonomous_transaction;
    begin
        update PyTL_Interfaces_Batches
        set LOCKED_BY = NULL
        where LOCKED_BY = UNLOCK_LOCKED_BY;

        commit;
        return;
    end unlock_pytl_interfaces_batches;
--------------------------------------------------------------------------------
    function get_and_lock_pytl_interfaces_records(OUTPUT_RECRD_UID_LIST varchar2, LOCK_BY varchar2) return T_PYTL_INTERFACES_RECORDS_TABLE pipelined
    as
        pragma autonomous_transaction;
        PYTL_INTERFACES_RECORDS_COLLECTION T_PYTL_INTERFACES_RECORDS_TABLE;
    begin
        select *
        bulk collect into PYTL_INTERFACES_RECORDS_COLLECTION
        from PyTL_Interfaces_Records
        where
            LOCKED_BY is null
            and OUTPUT_RECRD_UID in (
                    select regexp_substr(OUTPUT_RECRD_UID_LIST, '[^,]+', 1, level) from dual
                    connect by level <= length(regexp_replace(OUTPUT_RECRD_UID_LIST, '[^,]+')) + 1
            )
        for update of LOCKED_BY skip locked;

        if PYTL_INTERFACES_RECORDS_COLLECTION.count > 0 then
            for i in PYTL_INTERFACES_RECORDS_COLLECTION.first .. PYTL_INTERFACES_RECORDS_COLLECTION.last
            loop
                update PyTL_Interfaces_Records
                set LOCKED_BY = LOCK_BY
                where UNIQUE_ID = PYTL_INTERFACES_RECORDS_COLLECTION(i).UNIQUE_ID;
            end loop;
            commit;

            for i in PYTL_INTERFACES_RECORDS_COLLECTION.first .. PYTL_INTERFACES_RECORDS_COLLECTION.last
            loop
                pipe row (PYTL_INTERFACES_RECORDS_COLLECTION(i));
            end loop;
        else
            rollback;
        end if;

        return;
    end get_and_lock_pytl_interfaces_records;
--------------------------------------------------------------------------------
    procedure unlock_pytl_interfaces_records(UNLOCK_LOCKED_BY varchar2)
    as
        pragma autonomous_transaction;
    begin
        update PyTL_Interfaces_Records
        set LOCKED_BY = NULL
        where LOCKED_BY = UNLOCK_LOCKED_BY;

        commit;
        return;
    end unlock_pytl_interfaces_records;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
end PyTL_Interfaces_Utils;
/
commit;
/
exit;
