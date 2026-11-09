# Ejecutar desde PowerShell dentro de la carpeta raíz del proyecto.
# Esta secuencia instala/descarga solo los modelos locales: no hay API de pago.
$ErrorActionPreference = 'Stop'
Write-Host 'TESERACTA - Instalador auxiliar local' -ForegroundColor Cyan
Write-Host '1) Ollama debe estar instalado desde https://ollama.com/download/windows'
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
  Write-Host 'Ollama no está en PATH. Instálalo y abre una nueva terminal.' -ForegroundColor Yellow
} else {
  Write-Host 'Descargando Qwen3 1.7B (~1,4 GB)...'
  ollama pull qwen3:1.7b
}
if (-not (Get-Command py -ErrorAction SilentlyContinue)) {
  Write-Host 'Falta Python. Instálalo desde https://www.python.org/downloads/windows/' -ForegroundColor Yellow
  exit 1
}
py -m venv .venv
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r voice\requirements.txt
& .\.venv\Scripts\python.exe voice\download_model.py
Write-Host 'Listo. Ejecuta: .\.venv\Scripts\python.exe voice\server.py' -ForegroundColor Green
