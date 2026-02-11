@echo off
setlocal enabledelayedexpansion

set "ENV_HOME=%USERPROFILE%\.uv"
set "cmd=%~1"

if "%cmd%"=="" goto :usage

if /I "%cmd%"=="create" goto :create
if /I "%cmd%"=="remove" goto :remove
if /I "%cmd%"=="activate" goto :activate
if /I "%cmd%"=="deactivate" goto :deactivate
if /I "%cmd%"=="info" goto :info

:: Default: forward everything to uv
uv %*
exit /b %ERRORLEVEL%

:usage
echo Usage: pv COMMAND [ARGS]
echo.
echo Commands:
echo   create ENV [ARGS]     Create environment and initialize
echo   activate ENV          Activate environment and set UV_PROJECT
echo   deactivate ENV        Deactivate environment
echo   remove [-y] ENV       Remove environment (asks for confirmation)
echo   info                  Show environment info
echo.
echo Examples:
echo   pv create myenv
echo   pv activate myenv
echo   pv remove -y myenv
exit /b 0

:: Create new environment
:create
set "ENV=%~2"
set "UV_PROJECT=%ENV_HOME%\%ENV%"

if exist "%UV_PROJECT%" (
    echo Environment exists at "%UV_PROJECT%"
) else (
    mkdir "%UV_PROJECT%"

    :: Drop the first two args, then call uv with the remaining args
    set "ARGS="
    for /f "tokens=3* delims= " %%A in ("%*") do set "ARGS=%%A %%B"

    uv init !ARGS!
    uv sync
    echo Environment "%ENV%" created at "%UV_PROJECT%"
    echo:
    echo Activate the environment using `pv activate %ENV%`
)

:: Export UV_PROJECT to the parent shell (persist after setlocal)
for /f "delims=" %%A in ('echo(^!UV_PROJECT^!') do endlocal & set "UV_PROJECT=%%A"
exit /b

:: Activate existing environment
:activate
set "ENV=%~2"
    set "UV_PROJECT=%ENV_HOME%\%ENV%"

    :: Export UV_PROJECT to the parent shell, then call the activate script in that shell
    for /f "delims=" %%A in ('echo(^!UV_PROJECT^!') do endlocal & set "UV_PROJECT=%%A"

    set "ACTIVATE=%UV_PROJECT%\.venv\Scripts\activate.bat"
    if exist "%ACTIVATE%" (
        call "%ACTIVATE%"
    ) else (
        echo Environment "%ENV%" not found
    )
    exit /b

:deactivate
set "ENV=%~2"
set "UV_PROJECT=%ENV_HOME%\%ENV%"

    :: Export UV_PROJECT to the parent shell, then call the deactivate script in that shell
    for /f "delims=" %%A in ('echo(^!UV_PROJECT^!') do endlocal & set "UV_PROJECT=%%A"

    set "DEACTIVATE=%UV_PROJECT%\.venv\Scripts\deactivate.bat"
    if exist "%DEACTIVATE%" (
        call "%DEACTIVATE%"
    )
    exit /b

:remove
set "ENV="
set "FORCE=0"
set /a count=0

:: Parse args: allow `pv remove -y name` or `pv remove name -y`
for %%A in (%*) do (
    set /a count+=1
    if !count! gtr 1 (
        if /I "%%~A"=="-y" (
            set "FORCE=1"
        ) else (
            if not defined ENV set "ENV=%%~A"
        )
    )
)

if "%ENV%"=="" (
    echo Usage: pv remove [-y] ENV
    exit /b 1
)

set "UV_PROJECT=%ENV_HOME%\%ENV%"

if not exist "%UV_PROJECT%" (
    echo Environment "%ENV%" not found.
    exit /b 1
)

if "%FORCE%"=="0" (
    set /p CONF=Remove environment "%ENV%" at "%UV_PROJECT%"? [y/N] 
    if "!CONF!"=="" set "CONF=n"
    if /I "!CONF!" NEQ "y" (
        echo Aborted.
        exit /b 1
    )
)

echo Removing environment "%ENV%" at "%UV_PROJECT%"...
rmdir /s /q "%UV_PROJECT%"
if exist "%UV_PROJECT%" (
    echo Failed to remove "%UV_PROJECT%".
    exit /b 1
)

echo Removed "%UV_PROJECT%".
:: Clear UV_PROJECT in the parent shell (persist empty value)
endlocal & set "UV_PROJECT="
exit /b 0

:info
set "found=0"
if not exist "%ENV_HOME%" (
    echo No environments directory at "%ENV_HOME%".
    exit /b 0
)

for /d %%D in ("%ENV_HOME%\*") do (
    if "!found!"=="0" (
        echo Available environments in "%ENV_HOME%":
        set "found=1"
    )
    echo  - %%~nD
)

if "!found!"=="0" (
    echo No environments found in "%ENV_HOME%".
)
exit /b 0