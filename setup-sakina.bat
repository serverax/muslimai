@echo off
REM Project Sakina - Windows Setup Script
REM Usage: setup-sakina.bat

setlocal enabledelayedexpansion
cd /d %~dp0

set PROJECT_NAME=SakinaAL
set TIMESTAMP=%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%

echo.
echo ===================================================
echo Project Sakina - Automated Windows Setup
echo ===================================================
echo.

REM Check for Git
where git >nul 2>nul
if errorlevel 1 (
    echo WARNING: Git not found. Install from: https://git-scm.com
) else (
    echo [OK] Git found
)

REM Check for Docker
where docker >nul 2>nul
if errorlevel 1 (
    echo WARNING: Docker not found. Install Docker Desktop from: https://www.docker.com/products/docker-desktop
) else (
    echo [OK] Docker found
)

REM Check for kubectl
where kubectl >nul 2>nul
if errorlevel 1 (
    echo WARNING: kubectl not found (install from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/)
) else (
    echo [OK] kubectl found
)

REM Check for Rust
where cargo >nul 2>nul
if errorlevel 1 (
    echo WARNING: Rust not found (install from: https://rustup.rs/)
) else (
    echo [OK] Rust found
)

REM Check for Flutter
where flutter >nul 2>nul
if errorlevel 1 (
    echo WARNING: Flutter not found (install from: https://flutter.dev/docs/get-started/install)
) else (
    echo [OK] Flutter found
)

echo.
echo Creating directory structure...
echo.

REM Main directories
set DIRS=sakina-backend\src\handlers
set DIRS=!DIRS! sakina-backend\src\models
set DIRS=!DIRS! sakina-backend\src\services
set DIRS=!DIRS! sakina-backend\db
set DIRS=!DIRS! sakina-backend\tests
set DIRS=!DIRS! sakina-backend\.github\workflows
set DIRS=!DIRS! sakina-frontend\lib\config
set DIRS=!DIRS! sakina-frontend\lib\models
set DIRS=!DIRS! sakina-frontend\lib\services
set DIRS=!DIRS! sakina-frontend\lib\screens
set DIRS=!DIRS! sakina-frontend\lib\widgets
set DIRS=!DIRS! sakina-frontend\lib\providers
set DIRS=!DIRS! sakina-frontend\lib\l10n
set DIRS=!DIRS! sakina-frontend\.github\workflows
set DIRS=!DIRS! sakina-infra\helm
set DIRS=!DIRS! sakina-infra\manifests
set DIRS=!DIRS! sakina-infra\network
set DIRS=!DIRS! sakina-infra\storage
set DIRS=!DIRS! sakina-infra\volumes
set DIRS=!DIRS! sakina-infra\scripts
set DIRS=!DIRS! sakina-docs\architecture
set DIRS=!DIRS! sakina-docs\api
set DIRS=!DIRS! sakina-docs\guides
set DIRS=!DIRS! sakina-docs\runbooks
set DIRS=!DIRS! sakina-tests\integration
set DIRS=!DIRS! sakina-tests\e2e
set DIRS=!DIRS! sakina-tests\unit
set DIRS=!DIRS! .github\workflows

for %%D in (!DIRS!) do (
    if not exist "%%D" (
        mkdir "%%D"
        echo [OK] Created: %%D
    )
)

echo.
echo ===================================================
echo Setup Complete!
echo ===================================================
echo.
echo Next steps:
echo 1. Open PowerShell as Administrator
echo 2. Run: cd %CD%
echo 3. Run: .\deploy.bat
echo.
echo Or manually:
echo 1. Enable Kubernetes in Docker Desktop Settings
echo 2. Run: kubectl cluster-info
echo 3. Run: make setup-k8s
echo 4. Run: make dev-start
echo.

pause
