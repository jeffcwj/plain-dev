param(
    [switch]$SkipPull,
    [switch]$KeepConflicting
)

$ErrorActionPreference = "Stop"

$HomeDir = [Environment]::GetFolderPath("UserProfile")
$AgentsSkillsDir = Join-Path $HomeDir ".agents\skills"
$PlainDevDir = Join-Path $AgentsSkillsDir "plain-dev"
$SoberDir = Join-Path $AgentsSkillsDir "sober"
$ScriptRepoDir = Split-Path -Parent $PSScriptRoot

$PlainDevRepo = "https://github.com/jeffcwj/plain-dev.git"
$SoberRepo = "https://github.com/jeffcwj/sober.git"

function Ensure-GitRepo {
    param([string]$TargetDir, [string]$RepoUrl)
    if (Test-Path (Join-Path $TargetDir ".git")) {
        if (-not $SkipPull) {
            $dirty = git -C $TargetDir status --porcelain
            if (-not $dirty) {
                Write-Host "[sync] git pull $TargetDir"
                git -C $TargetDir pull --ff-only | Out-Null
            } else {
                Write-Host "[skip] $TargetDir 有未提交改动，跳过 pull"
            }
        }
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TargetDir) | Out-Null
        Write-Host "[clone] $RepoUrl -> $TargetDir"
        git clone $RepoUrl $TargetDir
    }
}

function Ensure-SkillLink {
    param([string]$ClaudeSkillsDir, [string]$AgentsDir)
    if (-not (Test-Path $ClaudeSkillsDir)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ClaudeSkillsDir) | Out-Null
        cmd /c mklink /J "$ClaudeSkillsDir" "$AgentsDir" | Out-Null
        Write-Host "[link] $ClaudeSkillsDir -> $AgentsDir"
        return
    }
    $item = Get-Item $ClaudeSkillsDir -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Host "[ok] $ClaudeSkillsDir 已链接到 $AgentsDir"
        return
    }
    foreach ($name in @("plain-dev", "sober")) {
        $dst = Join-Path $ClaudeSkillsDir $name
        $src = Join-Path $AgentsDir $name
        if (-not (Test-Path $dst)) {
            cmd /c mklink /J "$dst" "$src" | Out-Null
            Write-Host "[link] $dst -> $src"
        }
    }
}

function Merge-ManagedBlock {
    param([string]$TargetPath, [string]$BlockContent)
    $startMarker = "<!-- plain-dev:START -->"
    $endMarker = "<!-- plain-dev:END -->"
    $managed = "$startMarker`r`n$($BlockContent.Trim())`r`n$endMarker"

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TargetPath) | Out-Null
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    if (-not (Test-Path $TargetPath)) {
        $fresh = "# 全局规则`r`n`r`n$managed`r`n"
        [IO.File]::WriteAllText($TargetPath, $fresh, $utf8NoBom)
        Write-Host "[write] $TargetPath"
        return
    }

    $existing = [IO.File]::ReadAllText($TargetPath, $utf8NoBom)
    $pattern = [regex]::Escape($startMarker) + "[\s\S]*?" + [regex]::Escape($endMarker)
    if ([regex]::IsMatch($existing, $pattern)) {
        $updated = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $managed }, 1)
    } elseif ([string]::IsNullOrWhiteSpace($existing)) {
        $updated = "# 全局规则`r`n`r`n$managed`r`n"
    } else {
        $updated = "$managed`r`n`r`n$($existing.TrimStart())"
    }

    [IO.File]::WriteAllText($TargetPath, $updated, $utf8NoBom)
    Write-Host "[sync] $TargetPath"
}

function Disable-SkillIfPresent {
    param([string]$SkillPath, [string]$BackupDir)
    if (Test-Path $SkillPath) {
        $name = Split-Path -Leaf $SkillPath
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        $dest = Join-Path $BackupDir $name
        if (Test-Path $dest) {
            Remove-Item -Recurse -Force $dest
        }
        Move-Item -Path $SkillPath -Destination $dest
        Write-Host "[isolate] $SkillPath -> $dest"
    }
}

# 1. 确保 plain-dev 与 sober 均部署在 ~/.agents/skills/
New-Item -ItemType Directory -Force -Path $AgentsSkillsDir | Out-Null
if ((Resolve-Path $ScriptRepoDir).Path -ieq $PlainDevDir) {
    Ensure-GitRepo -TargetDir $PlainDevDir -RepoUrl $PlainDevRepo
} else {
    Ensure-GitRepo -TargetDir $PlainDevDir -RepoUrl $PlainDevRepo
}
Ensure-GitRepo -TargetDir $SoberDir -RepoUrl $SoberRepo

# 2. 链接 ~/.claude/skills -> ~/.agents/skills
Ensure-SkillLink -ClaudeSkillsDir (Join-Path $HomeDir ".claude\skills") -AgentsDir $AgentsSkillsDir

# 3. 统一写入全局 AGENTS.md（Claude Code / OpenCode / Codex）
$GlobalTemplatePath = Join-Path $PlainDevDir "global\AGENTS.md"
if (-not (Test-Path $GlobalTemplatePath)) {
    $GlobalTemplatePath = Join-Path $ScriptRepoDir "global\AGENTS.md"
}
$GlobalContent = [IO.File]::ReadAllText($GlobalTemplatePath, (New-Object System.Text.UTF8Encoding($false)))

$Targets = @(
    (Join-Path $HomeDir ".claude\AGENTS.md"),
    (Join-Path $HomeDir ".config\opencode\AGENTS.md"),
    (Join-Path $HomeDir ".codex\AGENTS.md")
)
foreach ($t in $Targets) {
    Merge-ManagedBlock -TargetPath $t -BlockContent $GlobalContent
}

# 4. 提醒旧 ~/.claude/CLAUDE.md（最新 Claude Code 已统一读 AGENTS.md）
$LegacyClaudeMd = Join-Path $HomeDir ".claude\CLAUDE.md"
if (Test-Path $LegacyClaudeMd) {
    Write-Host "[notice] 检测到旧文件 $LegacyClaudeMd（最新 Claude Code 已统一读 AGENTS.md），请确认无需保留后手动删除"
}

# 5. 默认隔离易与 GPT 冲突的自动触发技能（可逆备份到 skills-disabled/）
if (-not $KeepConflicting) {
    Disable-SkillIfPresent -SkillPath (Join-Path $AgentsSkillsDir "pua") -BackupDir (Join-Path $HomeDir ".agents\skills-disabled")
    Disable-SkillIfPresent -SkillPath (Join-Path $HomeDir ".config\opencode\skills\verification-planning") -BackupDir (Join-Path $HomeDir ".config\opencode\skills-disabled")
}

Write-Host "`n部署完成：plain-dev + sober 及全局 AGENTS.md 已全部就绪。"
