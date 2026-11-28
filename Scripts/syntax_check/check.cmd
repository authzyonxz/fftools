@echo off
rem Verification-only syntax check of the Objective-C sources against the stub SDK.
rem Not part of the app build; used on machines without the iOS SDK.
setlocal enabledelayedexpansion
set CLANG="C:\Program Files\LLVM\bin\clang.exe"
set STUBS=%~dp0stubs
set ROOT=%~dp0..\..
set FAILED=0
for %%F in ("%ROOT%\Sources\*.m" "%ROOT%\Sources\UI\*.m") do (
    echo === %%~nxF
    %CLANG% -fsyntax-only -x objective-c -fblocks -fobjc-arc -fobjc-runtime=ios-15.0 --target=arm64-apple-ios15.0 -Wno-everything -I"%STUBS%" -I"%ROOT%\Sources" -I"%ROOT%\Sources\UI" -I"%ROOT%\Sources\Vendor" -I"%ROOT%\Sources\Auth" "%%F"
    if errorlevel 1 set FAILED=1
)
exit /b %FAILED%
