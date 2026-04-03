@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
color 0A
cls

echo.
echo  ╔═══════════════════════════════════════════════════════════════╗
echo  ║                    GITHUB RELEASE MANAGER                     ║
echo  ╚═══════════════════════════════════════════════════════════════╝
echo.

rem Configurações
set PROJECT_NAME=Programa_ERP
set SOURCE_RELEASES_PATH=C:\Users\lucas\source\repos\AdaSysE\Programa_ERP\Releases
set VERSION_FILE=C:\Users\lucas\source\repos\AdaSysE\Programa_ERP\last_version.txt
set LOCAL_RELEASES_PATH=releases
set GITHUB_TOKEN=%GITHUB_PAT%
set GITHUB_REPO=AdaSysE/AdaUpdates

rem Verificar se arquivo de versão existe
if not exist "%VERSION_FILE%" (
    echo   ✗ Arquivo de versao nao encontrado em: %VERSION_FILE%
    pause >nul
    exit /b 1
)

rem Ler versão
set /p VERSION=<%VERSION_FILE%
echo   ► Versao a ser publicada: !VERSION!
echo.

rem Verificar arquivos fonte
if not exist "%SOURCE_RELEASES_PATH%\Setup.exe" (
    echo   ✗ Setup.exe nao encontrado. Execute o build do Squirrel primeiro.
    pause >nul
    exit /b 1
)
if not exist "%SOURCE_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" (
    echo   ✗ Pacote full nao encontrado. Execute o build do Squirrel primeiro.
    pause >nul
    exit /b 1
)
if not exist "%SOURCE_RELEASES_PATH%\RELEASES" (
    echo   ✗ Arquivo RELEASES nao encontrado. Execute o build do Squirrel primeiro.
    pause >nul
    exit /b 1
)

echo   ► Copiando arquivos para repositorio publico...
echo.

if exist "%LOCAL_RELEASES_PATH%\*" del /Q "%LOCAL_RELEASES_PATH%\*" >nul 2>&1

echo   [1/5] Copiando Setup.exe...
copy "%SOURCE_RELEASES_PATH%\Setup.exe" "%LOCAL_RELEASES_PATH%\Setup.exe" >nul 2>&1

echo   [2/5] Copiando pacote full...
copy "%SOURCE_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" "%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" >nul 2>&1

echo   [3/5] Copiando arquivo RELEASES...
copy "%SOURCE_RELEASES_PATH%\RELEASES" "%LOCAL_RELEASES_PATH%\RELEASES" >nul 2>&1

set DELTA_EXISTS=0
if exist "%SOURCE_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-delta.nupkg" (
    echo   [4/5] Copiando pacote delta...
    copy "%SOURCE_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-delta.nupkg" "%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-delta.nupkg" >nul 2>&1
    set DELTA_EXISTS=1
) else (
    echo   [4/5] Pacote delta nao encontrado (normal para primeira versao)
)

echo   [5/5] Verificando arquivos copiados...
if not exist "%LOCAL_RELEASES_PATH%\Setup.exe" goto :copy_error
if not exist "%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" goto :copy_error
if not exist "%LOCAL_RELEASES_PATH%\RELEASES" goto :copy_error

echo.
echo   ► Enviando para GitHub...
echo.

echo   [1/4] Adicionando arquivos ao Git...
git add .gitignore "%LOCAL_RELEASES_PATH%\RELEASES" >nul 2>&1

echo   [2/4] Commitando alteracoes...
git commit -m "Release v!VERSION!" >nul 2>&1

echo   [3/4] Enviando para repositorio...
git push origin main >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo   ✗ Erro ao enviar para repositorio
    pause >nul
    exit /b 1
)

echo   [4/4] Criando release no GitHub...

rem Criar release via API
curl -s -X POST ^
  -H "Authorization: token !GITHUB_TOKEN!" ^
  -H "Content-Type: application/json" ^
  -d "{\"tag_name\":\"v!VERSION!\",\"name\":\"Ada ERP v!VERSION!\",\"body\":\"Nova versao do Ada ERP com melhorias e correcoes.\",\"draft\":false,\"prerelease\":false,\"make_latest\":\"true\"}" ^
  "https://api.github.com/repos/!GITHUB_REPO!/releases" > "%TEMP%\release_response.json" 2>&1

rem Extrair upload_url do response
for /f "tokens=2 delims=:/ " %%a in ('findstr /i "upload_url" "%TEMP%\release_response.json"') do (
    set RELEASE_ID=%%a
    goto :got_id
)
:got_id

rem Extrair ID da release de forma mais confiável
for /f "tokens=1,2 delims=:," %%a in ('type "%TEMP%\release_response.json"') do (
    if "%%a"=="  \"id\"" (
        set RELEASE_ID=%%b
        set RELEASE_ID=!RELEASE_ID: =!
        goto :upload_assets
    )
)

:upload_assets
if "!RELEASE_ID!"=="" (
    echo   ✗ Erro ao criar release no GitHub
    echo   ✗ Verifique sua conexao e permissoes
    pause >nul
    exit /b 1
)

set UPLOAD_URL=https://uploads.github.com/repos/!GITHUB_REPO!/releases/!RELEASE_ID!/assets

echo   ► Enviando assets da release...

echo   [1/4] Enviando Setup.exe...
curl -s -X POST -H "Authorization: token !GITHUB_TOKEN!" -H "Content-Type: application/octet-stream" ^
  --data-binary @"%LOCAL_RELEASES_PATH%\Setup.exe" ^
  "!UPLOAD_URL!?name=Setup.exe" >nul 2>&1

echo   [2/4] Enviando pacote full...
curl -s -X POST -H "Authorization: token !GITHUB_TOKEN!" -H "Content-Type: application/octet-stream" ^
  --data-binary @"%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" ^
  "!UPLOAD_URL!?name=%PROJECT_NAME%-!VERSION!-full.nupkg" >nul 2>&1

if !DELTA_EXISTS! EQU 1 (
    echo   [3/4] Enviando pacote delta...
    curl -s -X POST -H "Authorization: token !GITHUB_TOKEN!" -H "Content-Type: application/octet-stream" ^
      --data-binary @"%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-delta.nupkg" ^
      "!UPLOAD_URL!?name=%PROJECT_NAME%-!VERSION!-delta.nupkg" >nul 2>&1
) else (
    echo   [3/4] Sem pacote delta.
)

echo   [4/4] Enviando RELEASES...
curl -s -X POST -H "Authorization: token !GITHUB_TOKEN!" -H "Content-Type: application/octet-stream" ^
  --data-binary @"%LOCAL_RELEASES_PATH%\RELEASES" ^
  "!UPLOAD_URL!?name=RELEASES" >nul 2>&1

echo.
echo  ╔═══════════════════════════════════════════════════════════════╗
echo  ║                    RELEASE PUBLICADA                         ║
echo  ╚═══════════════════════════════════════════════════════════════╝
echo.
echo   ✓ Release v!VERSION! criada com sucesso!
echo   ✓ https://github.com/!GITHUB_REPO!/releases/tag/v!VERSION!
echo.
echo   Agora os usuarios poderao atualizar automaticamente!
goto :end

:copy_error
echo   ✗ Erro ao copiar arquivos
pause >nul
exit /b 1

:end
echo.
echo   Pressione qualquer tecla para finalizar...
pause >nul
