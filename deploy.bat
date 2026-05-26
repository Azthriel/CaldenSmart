@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

:: ============================================================
::  CaldenSmart - Deploy Script
::  Lee version desde pubspec.yaml, genera ZIP y AAB
:: ============================================================

set "APP_DIR=C:\Desktop\caldensmart"
set "VERSIONS_DIR=C:\Desktop\Copia de versiones"
set "UPLOAD_DIR=C:\Desktop\Versión a subir"
set "PUBSPEC=%APP_DIR%\pubspec.yaml"
set "WINRAR=C:\Program Files\WinRAR\WinRAR.exe"

:: ── Verificar que existe pubspec.yaml ────────────────────────
if not exist "%PUBSPEC%" (
    echo [ERROR] No se encontro pubspec.yaml en %APP_DIR%
    pause & exit /b 1
)

:: ── Leer version desde pubspec.yaml ─────────────────────────
for /f "tokens=2 delims=: " %%v in ('findstr /r "^version:" "%PUBSPEC%"') do (
    set "FULL_VERSION=%%v"
)

:: Quedarse solo con la parte antes del "+" (sin build number)
for /f "tokens=1 delims=+" %%v in ("!FULL_VERSION!") do (
    set "VERSION=%%v"
)

:: Limpiar espacios/CR que pueda traer el yaml
set "VERSION=!VERSION: =!"
set "VERSION=!VERSION:	=!"

if "!VERSION!"=="" (
    echo [ERROR] No se pudo leer la version de pubspec.yaml
    pause & exit /b 1
)

:: ── Cabecera ─────────────────────────────────────────────────
echo.
echo  ╔══════════════════════════════════════════╗
echo  ║       CaldenSmart  -  Deploy Script      ║
echo  ╠══════════════════════════════════════════╣
echo  ║  Version detectada : !VERSION!
echo  ╚══════════════════════════════════════════╝
echo.

:: ── Verificar carpetas destino ───────────────────────────────
if not exist "%VERSIONS_DIR%" mkdir "%VERSIONS_DIR%"
if not exist "%UPLOAD_DIR%"   mkdir "%UPLOAD_DIR%"

:: ============================================================
::  PASO 1 — ZIP con WinRAR
:: ============================================================
echo [1/3] Creando ZIP de la carpeta completa...
echo        Fuente  : %APP_DIR%
echo        Destino : %VERSIONS_DIR%\caldensmart!VERSION!.zip
echo.

set "ZIP_DEST=%VERSIONS_DIR%\caldensmart!VERSION!.zip"

if exist "%WINRAR%" (
    "%WINRAR%" a -afzip -r -ep1 "!ZIP_DEST!" "%APP_DIR%\"
) else (
    :: Fallback: PowerShell si no esta instalado WinRAR
    echo [AVISO] WinRAR no encontrado en %WINRAR%, usando PowerShell...
    powershell -Command "Compress-Archive -Path '%APP_DIR%\*' -DestinationPath '!ZIP_DEST!' -Force"
)

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Fallo la creacion del ZIP.
    pause & exit /b 1
)
echo  OK - ZIP generado correctamente.
echo.

:: ============================================================
::  PASO 2 — flutter build appbundle
:: ============================================================
echo [2/3] Ejecutando flutter build appbundle...
echo.

cd /d "%APP_DIR%"
call flutter build appbundle

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] flutter build appbundle fallo.
    pause & exit /b 1
)
echo.
echo  OK - Build completado.
echo.

:: ============================================================
::  PASO 3 — Renombrar y mover el .aab
:: ============================================================
echo [3/3] Moviendo AppBundle a "Version a subir"...

set "AAB_SRC=%APP_DIR%\build\app\outputs\bundle\release\app-release.aab"
set "AAB_DEST=%UPLOAD_DIR%\CaldenSmart!VERSION!.aab"

if not exist "!AAB_SRC!" (
    echo [ERROR] No se encontro el .aab en:
    echo         !AAB_SRC!
    pause & exit /b 1
)

copy /Y "!AAB_SRC!" "!AAB_DEST!" >nul

if %errorlevel% neq 0 (
    echo [ERROR] No se pudo copiar el .aab.
    pause & exit /b 1
)
echo  OK - AAB copiado correctamente.
echo.

:: ============================================================
::  RESUMEN FINAL
:: ============================================================
echo  ╔══════════════════════════════════════════╗
echo  ║          Deploy Finalizado!              ║
echo  ╠══════════════════════════════════════════╣
echo  ║  Version    : !VERSION!
echo  ║  ZIP        : caldensmart!VERSION!.zip
echo  ║  AppBundle  : CaldenSmart!VERSION!.aab
echo  ╚══════════════════════════════════════════╝
echo.

:: Sonido de notificación
echo 

pause