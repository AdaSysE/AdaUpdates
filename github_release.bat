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

rem Verificar se arquivo de versão existe
if not exist "%VERSION_FILE%" (
    echo   ✗ Arquivo de versao nao encontrado em: %VERSION_FILE%
    echo   ✗ Execute o build do Squirrel primeiro.
    pause >nul
    exit /b 1
)

rem Ler versão
set /p VERSION=<%VERSION_FILE%
echo   ► Versao a ser publicada: !VERSION!
echo.

rem Verificar se os arquivos existem na pasta source
if not exist "%SOURCE_RELEASES_PATH%\Setup.exe" (
    echo   ✗ Setup.exe nao encontrado em: %SOURCE_RELEASES_PATH%
    echo   ✗ Execute o build do Squirrel primeiro.
    pause >nul
    exit /b 1
)

if not exist "%SOURCE_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" (
    echo   ✗ Pacote full nao encontrado: %PROJECT_NAME%-!VERSION!-full.nupkg
    echo   ✗ Execute o build do Squirrel primeiro.
    pause >nul
    exit /b 1
)

if not exist "%SOURCE_RELEASES_PATH%\RELEASES" (
    echo   ✗ Arquivo RELEASES nao encontrado em: %SOURCE_RELEASES_PATH%
    echo   ✗ Execute o build do Squirrel primeiro.
    pause >nul
    exit /b 1
)

echo   ► Copiando arquivos para repositorio publico...
echo.

rem Limpar pasta releases local
if exist "%LOCAL_RELEASES_PATH%\*" del /Q "%LOCAL_RELEASES_PATH%\*" >nul 2>&1

rem Copiar arquivos necessários
echo   [1/5] Copiando Setup.exe...
copy "%SOURCE_RELEASES_PATH%\Setup.exe" "%LOCAL_RELEASES_PATH%\Setup.exe" >nul 2>&1

echo   [2/5] Copiando pacote full...
copy "%SOURCE_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" "%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" >nul 2>&1

echo   [3/5] Copiando arquivo RELEASES...
copy "%SOURCE_RELEASES_PATH%\RELEASES" "%LOCAL_RELEASES_PATH%\RELEASES" >nul 2>&1

rem Copiar delta se existir
if exist "%SOURCE_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-delta.nupkg" (
    echo   [4/5] Copiando pacote delta...
    copy "%SOURCE_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-delta.nupkg" "%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-delta.nupkg" >nul 2>&1
    set DELTA_EXISTS=1
) else (
    echo   [4/5] Pacote delta nao encontrado (normal para primeira versao)
    set DELTA_EXISTS=0
)

echo   [5/5] Verificando arquivos copiados...

rem Verificar se os arquivos foram copiados
set FILES_OK=1
if not exist "%LOCAL_RELEASES_PATH%\Setup.exe" set FILES_OK=0
if not exist "%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" set FILES_OK=0
if not exist "%LOCAL_RELEASES_PATH%\RELEASES" set FILES_OK=0

if !FILES_OK! EQU 0 (
    echo   ✗ Erro ao copiar arquivos
    pause >nul
    exit /b 1
)

echo.
echo   ► Enviando para GitHub...
echo.

echo   [1/4] Adicionando arquivos ao Git...
git add . >nul 2>&1

echo   [2/4] Commitando alteracoes...
git commit -m "Release v!VERSION!" >nul 2>&1

echo   [3/4] Enviando para repositorio...
git push origin main >nul 2>&1

echo   [4/4] Criando release no GitHub...

rem Criar release com arquivos principais
if !DELTA_EXISTS! EQU 1 (
    gh release create v!VERSION! ^
        "%LOCAL_RELEASES_PATH%\Setup.exe" ^
        "%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" ^
        "%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-delta.nupkg" ^
        "%LOCAL_RELEASES_PATH%\RELEASES" ^
        --title "Ada ERP v!VERSION!" ^
        --notes "Nova versao do Ada ERP com melhorias e correções." ^
        --latest >nul 2>&1
) else (
    gh release create v!VERSION! ^
        "%LOCAL_RELEASES_PATH%\Setup.exe" ^
        "%LOCAL_RELEASES_PATH%\%PROJECT_NAME%-!VERSION!-full.nupkg" ^
        "%LOCAL_RELEASES_PATH%\RELEASES" ^
        --title "Ada ERP v!VERSION!" ^
        --notes "Nova versao do Ada ERP com melhorias e correções." ^
        --latest >nul 2>&1
)

if !ERRORLEVEL! EQU 0 (
    echo.
    echo  ╔═══════════════════════════════════════════════════════════════╗
    echo  ║                    RELEASE PUBLICADA                         ║
    echo  ╚═══════════════════════════════════════════════════════════════╝
    echo.
    echo   ✓ Release v!VERSION! criada com sucesso!
    echo   ✓ Arquivos copiados para repositorio publico
    echo   ✓ Release disponivel em: https://github.com/AdaSysE/AdaUpdates/releases/tag/v!VERSION!
    echo.
    echo   ► Arquivos na release:
    echo   ✓ Setup.exe
    echo   ✓ %PROJECT_NAME%-!VERSION!-full.nupkg
    if !DELTA_EXISTS! EQU 1 echo   ✓ %PROJECT_NAME%-!VERSION!-delta.nupkg
    echo   ✓ RELEASES
    echo.
    echo   Agora os usuarios poderao atualizar automaticamente!
) else (
    echo   ✗ Erro ao criar release no GitHub
    echo   ✗ Verifique sua conexao e permissoes
)

echo.
echo   Pressione qualquer tecla para finalizar...
pause >nul