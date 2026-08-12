@echo off
setlocal

set "PROJECT_DIR=%~dp0"
set "BUNDLED_GODOT=%PROJECT_DIR%.tools\godot-4.7.1\Godot_v4.7.1-stable_win64.exe"

if exist "%BUNDLED_GODOT%" (
  set "GODOT_EXE=%BUNDLED_GODOT%"
) else (
  where godot >nul 2>nul
  if errorlevel 1 (
    echo Pokedot could not find Godot 4.7.1.
    echo Open project.godot with Godot 4.7.1, or install Godot and add it to PATH.
    pause
    exit /b 1
  )
  set "GODOT_EXE=godot"
)

set "APPDATA=%PROJECT_DIR%.godot-user"
set "LOCALAPPDATA=%PROJECT_DIR%.godot-user"
start "Pokedot" "%GODOT_EXE%" --path "%PROJECT_DIR%"
