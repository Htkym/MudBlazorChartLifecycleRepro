param([switch]$Upstream, [switch]$Wasm)

$ErrorActionPreference = 'Stop'
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$project = if ($Wasm) { 'WasmRepro\WasmRepro.csproj' } else { 'Repro\Repro.csproj' }
$port = if ($Wasm) { 5288 } else { 5287 }
$arguments = @('run', '--project', (Join-Path $PSScriptRoot $project), '--no-launch-profile', '--urls', "http://127.0.0.1:$port")
if ($Upstream) {
    $arguments += '-p:UseUpstreamMudBlazor=true'
}
& dotnet @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
