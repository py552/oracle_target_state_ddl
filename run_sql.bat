@echo off

set "REPO=D:\REPO\pytl\pytl_jobs"

set "SQL_LIST=%~1"
if not defined SQL_LIST set "SQL_LIST=%~dpn0.txt"

set "WORK_DIR=%~dp0"
set "LOG_FILE=%~dp0\$log$"

setlocal EnableDelayedExpansion
for /f %%f in (%SQL_LIST%) do (
    set "SQL_FILE=%WORK_DIR%\%%f"
    set "CUR_LOG_FILE=%LOG_FILE%.%%f"
    echo *** "%REPO%\pytl_jobs\NIC\NIC_SqlPlus.bat" "ENV=%WORK_DIR%\DEV25.parm" "DB_CONNECTION_NAME=DB_STG_SRC_WLTURL" "SQL_FILE=!SQL_FILE!"
    call "%REPO%\pytl_jobs\NIC\NIC_SqlPlus.bat" "ENV=%WORK_DIR%\DEV25.parm" "DB_CONNECTION_NAME=DB_STG_SRC_WLTURL" "SQL_FILE=!SQL_FILE!" > "!CUR_LOG_FILE!" 2>&1
    set current_ERRORLEVEL=!ERRORLEVEL!

    echo -------------------------8^<-------------------------
    type "%LOG_FILE%.%%f"
    echo -------------------------8^<-------------------------

    echo current_ERRORLEVEL=1=!current_ERRORLEVEL!
    if !current_ERRORLEVEL! neq 0 @echo *** Error#1 with execution of '!SQL_FILE!'!&&echo *** Execution terminated!!&&exit -1

    grep "ERROR at line" "!CUR_LOG_FILE!" > nul
    set current_ERRORLEVEL=!ERRORLEVEL!
    echo current_ERRORLEVEL=2=!current_ERRORLEVEL!
    if !current_ERRORLEVEL! equ 0 @echo *** Error#2 with execution of '!SQL_FILE!'!&&echo *** Execution terminated!!&&exit -1

    del "%LOG_FILE%.%%f"
)
endlocal

exit
