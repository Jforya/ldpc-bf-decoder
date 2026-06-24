param(
    [string]$BaseMatrix = "",
    [int]$Frames = 120
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Iverilog = Join-Path $Root "_tools\iverilog\bin\iverilog.exe"
$Vvp = Join-Path $Root "_tools\iverilog\bin\vvp.exe"
$Sim = Join-Path $Root "sim.vvp"

function Invoke-Native {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE"
    }
}

Set-Location $Root

if (!(Test-Path $Iverilog) -or !(Test-Path $Vvp)) {
    throw "Icarus Verilog was not found under _tools\iverilog. Install it first or adjust this script."
}

if ($BaseMatrix -eq "") {
    $matches = Get-ChildItem -Path $Root -Recurse -Filter "qc_peg_40_50_invc6dplopt_shift_inv.txt" |
        Where-Object { $_.FullName -notmatch "\\code\\" }
    if ($matches.Count -ne 1) {
        throw "Expected exactly one base matrix match, found $($matches.Count). Pass -BaseMatrix explicitly."
    }
    $BaseMatrix = $matches[0].FullName
}

Invoke-Native "node" @("tools\gen_rtl_inputs.js", $BaseMatrix, [string]$Frames)

Invoke-Native $Iverilog @(
    "-g2012", "-I", "rtl", "-o", $Sim,
    "rtl\bf_decoder_top.v", "rtl\syndrome_calc.v", "rtl\conflict_flip.v", "rtl\bf_tb.v"
)

Invoke-Native $Vvp @($Sim)

$gold = (Get-Content trace_gold.txt -Raw) -replace "`r`n", "`n"
$rtl = (Get-Content trace_rtl.txt -Raw) -replace "`r`n", "`n"
if ($gold -ne $rtl) {
    throw "trace_gold.txt and trace_rtl.txt differ"
}

Write-Host "trace diff: no differences"
