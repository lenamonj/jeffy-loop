#Requires -Version 5.1
# Jeffy installer: verifies prerequisites, installs the /jeffy skill (which
# ships the Stop hook loop engine), and registers the hook in ~/.claude/settings.json.
$ErrorActionPreference = "Stop"

Write-Host "Jeffy installer"
Write-Host ""

$ok = $true

# 1. Claude Code CLI (the one prerequisite this installer cannot install for you)
$claudeFound = [bool](Get-Command claude -ErrorAction SilentlyContinue)
if ($claudeFound) {
    Write-Host "[OK] Claude Code CLI found"
} else {
    Write-Host "[MISSING] Claude Code CLI. Install it first: https://claude.com/claude-code"
    $ok = $false
}

# 2. jq (required by Jeffy's Stop hook)
if (Get-Command jq -ErrorAction SilentlyContinue) {
    Write-Host "[OK] jq found"
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    try {
        $answer = Read-Host "[MISSING] jq is required by Jeffy's Stop hook. Install with winget now? (y/n)"
    } catch {
        $answer = ""
        Write-Host "[MISSING] jq, and the install prompt could not be answered (non-interactive run)."
    }
    if ($answer -eq "y") {
        winget install --id jqlang.jq --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Host "winget install failed. Install manually: winget install jqlang.jq"
            $ok = $false
        } else {
            Write-Host "[OK] jq installed (open a new terminal if it is not on PATH yet)"
        }
    } else {
        Write-Host "Skipped. Install later with: winget install jqlang.jq"
        $ok = $false
    }
} else {
    Write-Host "[MISSING] jq, and winget is not available to install it. Install jq manually: winget install jqlang.jq (or see https://jqlang.github.io/jq/download/)"
    $ok = $false
}

# 3. Install the skills (/jeffy and /cancel-jeffy). The jeffy skill folder
#    carries the Stop hook at hooks\stop-hook.sh, so the engine lands here too.
foreach ($name in @("jeffy", "cancel-jeffy")) {
    $src = Join-Path $PSScriptRoot "skills\$name\SKILL.md"
    if (-not (Test-Path $src)) {
        throw "skills\$name\SKILL.md not found next to this script. Run install.ps1 from the cloned repo."
    }
    $dest = Join-Path $HOME ".claude\skills\$name"
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $srcDir = Join-Path $PSScriptRoot "skills\$name"
    Copy-Item -Path (Join-Path $srcDir "*") -Destination $dest -Recurse -Force
    Write-Host "[OK] /$name skill installed to $dest"
}

# 4. Register the Stop hook (the loop engine) in ~/.claude/settings.json.
#    Idempotent: a settings file that already names the hook is left alone, and
#    an unparseable settings file is never overwritten. The command uses forward
#    slashes because it runs under bash (Git Bash on Windows).
# Built with nested Join-Path so the separators are native on every platform:
# the .NET write below does not translate backslashes on Linux the way the
# PowerShell provider cmdlets do.
$settingsDir = Join-Path $HOME ".claude"
$settingsPath = Join-Path $settingsDir "settings.json"
$hookScript = (Join-Path $HOME ".claude\skills\jeffy\hooks\stop-hook.sh") -replace '\\', '/'
$hookCmd = "bash `"$hookScript`""
$settings = $null
if ((Test-Path $settingsPath) -and ((Get-Item $settingsPath).Length -gt 0)) {
    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    } catch {
        Write-Host "[FAILED] $settingsPath is not valid JSON; fix it, then re-run this installer to register the hook."
        $ok = $false
    }
} else {
    $settings = New-Object psobject
}
if ($null -ne $settings) {
    $already = $false
    $upgrade = @()
    if ($settings.PSObject.Properties['hooks'] -and $settings.hooks.PSObject.Properties['Stop']) {
        foreach ($entry in @($settings.hooks.Stop)) {
            if ($null -eq $entry) { continue }
            foreach ($h in @($entry.hooks)) {
                if ($null -ne $h -and "$($h.command)" -like "*skills/jeffy/hooks/stop-hook.sh*") {
                    $already = $true
                    if (-not $h.PSObject.Properties['timeout']) { $upgrade += $h }
                }
            }
        }
    }
    if ($already -and $upgrade.Count -eq 0) {
        Write-Host "[OK] Jeffy Stop hook already registered in $settingsPath"
    } elseif ($already) {
        # Pre-1.2 registration: the hook now runs the project's verify command
        # at the converged stop, which the default hook timeout cannot
        # contain, so add the timeout field exactly once.
        try {
            foreach ($h in $upgrade) { $h | Add-Member -MemberType NoteProperty -Name timeout -Value 600 }
            [System.IO.File]::WriteAllText($settingsPath, (($settings | ConvertTo-Json -Depth 32) + "`n"))
            Write-Host "[OK] Jeffy Stop hook registration upgraded with a 600s timeout in $settingsPath"
        } catch {
            Write-Host "[FAILED] could not upgrade the Stop hook timeout in $settingsPath ($($_.Exception.Message)); add `"timeout`": 600 to the hook entry by hand and re-run to verify."
            $ok = $false
        }
    } else {
        try {
            $hookObj = [pscustomobject]@{ type = "command"; command = $hookCmd; timeout = 600 }
            $entryObj = [pscustomobject]@{ hooks = @($hookObj) }
            if (-not $settings.PSObject.Properties['hooks']) {
                $settings | Add-Member -MemberType NoteProperty -Name hooks -Value (New-Object psobject)
            }
            if (-not $settings.hooks.PSObject.Properties['Stop']) {
                $settings.hooks | Add-Member -MemberType NoteProperty -Name Stop -Value @()
            }
            $settings.hooks.Stop = @($settings.hooks.Stop) + $entryObj
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
            # WriteAllText writes UTF-8 without a BOM; Set-Content -Encoding UTF8
            # on Windows PowerShell 5.1 would prepend one, and a BOM breaks
            # strict JSON parsers reading settings.json.
            [System.IO.File]::WriteAllText($settingsPath, (($settings | ConvertTo-Json -Depth 32) + "`n"))
            Write-Host "[OK] Jeffy Stop hook registered in $settingsPath"
        } catch {
            Write-Host "[FAILED] could not update $settingsPath ($($_.Exception.Message)); add the Stop hook entry by hand (see README) and re-run to verify."
            $ok = $false
        }
    }
}

Write-Host ""
if ($ok) {
    Write-Host "Done. Start a new Claude Code session in any project and run: /jeffy"
} else {
    Write-Host "Skills installed, but fix the items above, then re-run this installer to verify."
    exit 1
}
