$ErrorActionPreference = "Stop"
if (-not (Test-Path .venv)) { python -m venv .venv }
. .venv/Scripts/Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
$env:PYTHONPATH = "$PWD"
uvicorn services.gateway.app:app --reload --host 0.0.0.0 --port 8080
