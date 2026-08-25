@echo off
chcp 65001 >nul
title Project Zomboid - Mod Tikanikligi Acici

REM PowerShell scriptini calistirma politikasini gecici olarak atlayarak baslatir.
REM (Sistem ayarlarini kalicI olarak degistirmez - sadece bu calistirma icin.)

set "PS1=%~dp0PZ_Mod_Tikanikligi_Ac.ps1"

if not exist "%PS1%" (
    echo.
    echo  [HATA] PZ_Mod_Tikanikligi_Ac.ps1 bulunamadi.
    echo         Bu .bat dosyasi ile ayni klasorde olmali.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"

if errorlevel 1 (
    echo.
    echo  Islem hata ile sonlandi.
    pause
)
