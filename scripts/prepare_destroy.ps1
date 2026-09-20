$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$terraform = Join-Path $repoRoot ".tools\terraform.exe"
$terraformDir = Join-Path $repoRoot "terraform"
$plan = Join-Path $repoRoot ".local\otus-dz02-destroy.tfplan"

if (-not (Test-Path -LiteralPath $terraform)) {
    throw "Terraform не найден в каталоге .tools"
}

$env:TF_CLI_CONFIG_FILE = Join-Path $repoRoot "terraform.rc"

& $terraform -chdir=$terraformDir plan -destroy -out=$plan
if ($LASTEXITCODE -ne 0) {
    throw "Не удалось сформировать план удаления"
}

& $terraform -chdir=$terraformDir show $plan
if ($LASTEXITCODE -ne 0) {
    throw "Не удалось показать план удаления"
}

Write-Host ""
Write-Host "План удаления сохранён локально:"
Write-Host $plan
Write-Host ""
Write-Host "После проверки выполните:"
Write-Host ".\.tools\terraform.exe -chdir=terraform apply .\.local\otus-dz02-destroy.tfplan"
