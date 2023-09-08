# vim: foldmethod=marker

# options {{{1
# PSReadLine {{{2

# Change the edit mode to Vi
Set-PSReadlineOption -EditMode Vi

# Set the indicator style for Vi normal mode
function OnViModeChange {
    if ($args[0] -eq 'Command') {
        # Set the cursor to a blinking block.
        Write-Host -NoNewLine "`e[1 q"
    } else {
        # Set the cursor to a blinking line.
        Write-Host -NoNewLine "`e[5 q"
    }
}
Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler $Function:OnViModeChange

# Enable auto suggestions like in fish
try {
  Set-PSReadlineOption -PredictionSource History
} catch [System.Management.Automation.ParameterBindingException] {
  # This means we deal with a version where this is not supported, just ignore
  # it
}

# KeyHandlers {{{3

Set-PSReadlineKeyHandler -ViMode Insert -Chord Ctrl+w -Function ViBackwardDeleteGlob

Set-PSReadlineKeyHandler -ViMode Insert -Chord Tab -Function MenuComplete

Set-PSReadlineKeyHandler -ViMode Insert -Chord Ctrl+RightArrow -Function AcceptNextSuggestionWord

# helper functions {{{1

function Pr_MinifyPath {
  Param (
    [string]
    $OrigPath,

    [uint32]
    $LastLength = 10
  )

  Write-Debug "Pr_MinifyPath($OrigPath, $LastLength)"

  $MatchResult = [Regex]::Matches($OrigPath, '\\')
  if ($MatchResult.Success) {
    $Separator = '\\'
  } else {
    $Separator = '/'
  }
  $Pieces = $OrigPath -split $Separator
  $AllButLast = $Pieces | Select-Object -SkipLast 1
  if ($Pieces[-1].Length -gt $LastLength) {
    $Last = "$($Pieces[-1].substring(0, $LastLength))…"
  } else {
    $Last = $Pieces[-1]
  }

  $AllButLast = ($AllButLast | foreach-object {
    if (($_.Length -gt 1) -and ($_[0] -eq '.')) {
      $_.substring(0, 2)
    } else {
      $_[0]
    }
  }) -join $Separator[0]

  Write-Debug "AllButLast: $AllButLast"
  Write-Debug "Last: $Last"

  if ($AllButLast) {
    $AllButLast, $Last -join $Separator[0]
  } else {
    $Last
  }
}

# theming {{{1
# helper functions {{{2

function Pr_CssColorToSGRParameters {
  Param ([string]$CssColor)

  $MatchResult = [Regex]::Matches($CssColor, '^#([0-9a-fA-F]{2}){3}$')

  if (!$MatchResult.Success) {
    Write-Error "Not a valid CSS color: $CssColor"
  }

  $Red   = [uint32]"0x$($MatchResult.Groups[1].Captures[0])"
  $Green = [uint32]"0x$($MatchResult.Groups[1].Captures[1])"
  $Blue  = [uint32]"0x$($MatchResult.Groups[1].Captures[2])"

  "2;$Red;$Green;$Blue"
}

function Pr_Fg {
  Param ([string]$CssColor)

  "$([char]0x1b)[38;$(Pr_CssColorToSGRParameters($CssColor))m"
}

function Pr_Fg_Default {
  "$([char]0x1b)[39m"
}

function Pr_Bg {
  Param ([string]$CssColor)

  "$([char]0x1b)[48;$(Pr_CssColorToSGRParameters($CssColor))m"
}

function Pr_Bg_Default {
  "$([char]0x1b)[49m"
}

function Pr_Bold {
  "$([char]0x1b)[1m"
}

function Pr_Italic {
  "$([char]0x1b)[3m"
}

function Pr_Reset {
  "$([char]0x1b)[0m"
}

# color definitions {{{2

$Pink          = '#ff00ff'
$Black         = '#000000'

$Red300        = '#e57373'
$Red500        = '#f44336'
$RedA100       = '#ff8a80'
$RedA200       = '#ff5252'
$Blue50        = '#e3f2fd'
$Blue500       = '#2196f3'
$Blue600       = '#1e88e5'
$LightBlueA100 = '#80d8ff'
$Cyan100       = '#b2ebf2'
$Teal500       = '#009688'
$Green50       = '#e8f5e9'
$Green500      = '#4caf50'
$Green600      = '#43a047'
$GreenA700     = '#00c853'
$LightGreen500 = '#8bc34a'
$Yellow500     = '#ffeb3b'
$Yellow600     = '#fdd835'
$Orange500     = '#ff9800'
$Orange600     = '#fb8c00'
$Grey50        = '#fafafa'
$Grey300       = '#e0e0e0'
$Grey400       = '#bdbdbd'
$Grey500       = '#9e9e9e'
$Grey700       = '#616161'

$Test          = "$(Pr_Fg($Pink))$(Pr_Bg($Black))"
$Default       = 'white'

# syntax colors {{{2

Set-PSReadLineOption -Colors @{
  Command            = Pr_Fg($Teal500)
  Comment            = Pr_Fg($Grey500)
  ContinuationPrompt = Pr_Fg($Grey400)
  Default            = Pr_Fg($Grey700)
  Emphasis           = Pr_Bg($Yellow500)
  Error              = "$(Pr_Fg($Grey50))$(Pr_Bg($Red500))"
  InlinePrediction   = Pr_Fg($Grey500)
  Keyword            = "$(Pr_Bold)$(Pr_Fg($Orange600))"
  Member             = Pr_Fg($Blue500)
  Number             = "$(Pr_Fg($Blue600))$(Pr_Bg($Blue50))"
  Operator           = Pr_Fg($Orange600)
  Parameter          = "$(Pr_Italic)$(Pr_Fg($Orange500))"
  Selection          = Pr_Bg($Cyan100)
  String             = "$(Pr_Fg($Green600))$(Pr_Bg($Green50))"
  Type               = Pr_Fg($Green500)
  Variable           = Pr_Fg($LightGreen500)
}

# host private data colors {{{2

if ($PSVersionTable.PSVersion.Major -ge 7) {
  (Get-Host).PrivateData.FormatAccentColor     = 'Green'
  (Get-Host).PrivateData.ErrorAccentColor      = 'Cyan'
}
(Get-Host).PrivateData.ErrorForegroundColor    = 'White'
(Get-Host).PrivateData.ErrorBackgroundColor    = 'DarkRed'
(Get-Host).PrivateData.WarningForegroundColor  = 'White'
(Get-Host).PrivateData.WarningBackgroundColor  = 'DarkYellow'
(Get-Host).PrivateData.DebugForegroundColor    = 'Yellow'
(Get-Host).PrivateData.DebugBackgroundColor    = 'Black'
(Get-Host).PrivateData.VerboseForegroundColor  = 'Yellow'
(Get-Host).PrivateData.VerboseBackgroundColor  = 'Black'
(Get-Host).PrivateData.ProgressForegroundColor = 'Black'
(Get-Host).PrivateData.ProgressBackgroundColor = 'Cyan'

# Prompt {{{1
# Continuation {{{2

if ($env:TERM -match '^xterm-256color' -or `
    $env:WT_SESSION -and `
    $PSVersionTable.PSVersion.Major -ge 6) {
  $SeparatorChar  = ''
  $SeparatorChar2 = ''
} else {
  $SeparatorChar  = '>'
  $SeparatorChar2 = '>'
}
Set-PSReadLineOption -ContinuationPrompt "$SeparatorChar"

# Syntax error indicator {{{2

# Set the text to change color in the prompt on syntax error
Set-PSReadLineOption -PromptText "$SeparatorChar "

# customize the prompt {{{2
# git prompt functions {{{3
# repo info {{{4

function pwsh_git_prompt_repo_info {
  $Result =
    (git rev-parse --git-dir --is-inside-git-dir --is-bare-repository 2>$null)

  if ($Result) {
    $Result[0],
    ($Result[1] -eq 'true'),
    ($Result[2] -eq 'true')
  }
}

# state info {{{4

function pwsh_git_prompt_state_info {
  Param (
    [string]
    $GitDir,

    [boolean]
    $InsideGitDir,

    [boolean]
    $BareRepo
  )

  $Detached = $False
  $LastTag = (git describe --tags --abbrev=0 2>$null)

  # Read the current operation and some additional info from git files.
  if (Test-Path -PathType Container -Path $GitDir\rebase-merge) {
    $Step = (Get-Content $GitDir\rebase-merge\msgnum)
    $Totel = (Get-Content $GitDir\rebase-merge\end)
    if (Test-Path -PathType Leaf -Path $GitDir\interactive) {
      $Operation = 'REBASE-i'
    } else {
      $Operation = 'REBASE-m'
    }
  } else {
    if (Test-Path -PathType Container -Path $GitDir\rebase-apply) {
      $Step = (Get-Content $GitDir\rebase-apply\next)
      $Totel = (Get-Content $GitDir\rebase-apply\last)
      if (Test-Path -PathType Leaf -Path $GitDir\rebase-apply\rebasing) {
        $Operation = 'REBASE'
      } elseif (Test-Path -PathType Leaf -Path $GitDir\rebase-apply\applying) {
        $Operation = 'AM'
      } else {
        $Operation = 'AM/REBASE'
      }
    } elseif (Test-Path -PathType Leaf -Path $GitDir\MERGE_HEAD) {
      $Operation = 'MERGING'
    } elseif (Test-Path -PathType Leaf -Path $GitDir\CHERRY_PICK_HEAD) {
      $Operation = 'CHERRY-PICKING'
    } elseif (Test-Path -PathType Leaf -Path $GitDir\REVERT_HEAD) {
      $Operation = 'REVERTING'
    } elseif (Test-Path -PathType Leaf -Path $GitDir\BISECT_LOG) {
      $Operation = 'BISECTING'
    }
  }

  # If there are steps and total, add it do the opration.
  if ($Step -and $Total) {
    $Operation += " $Step/$Total"
  }

  # Get a ref name to show.
  # First, set the branch name from a symbolic ref.
  $Branch = (git symbolic-ref --short HEAD 2>$null)
  $OpStatus = $LastExitCode
  if ($OpStatus -ne '' -and $OpStatus -ne 0) {
    # If the symbolic ref check returned non-zero, we are in a detached head
    # state.
    $Detached = $true
    # Instead get the closest newer ref name (branch or tag).
    $Branch = (git describe --contains --all HEAD 2>$null)
    $OpStatus = $LastExitCode
    if ($OpStatus -ne '' -and $OpStatus -ne 0) {
      # If this fails for some other reason, we just show the SHA of the commit.
      $Branch = (git rev-parse --short HEAD 2>$null)
      $OpStatus = $LastExitCode
      if ($OpStatus -ne '' -and $OpStatus -ne 0) {
        # If even that fails, use "unknown".
        $Branch = 'unknown'
      }
    }
  }

  # Check if we are inside a git dir or if the repo is a bare repo.
  if ($InsideGitDir -eq $true) {
    if ($BareRepo -eq $true) {
      $DirWarning = 'BARE'
    } else {
      $DirWarning = 'GIT DIR'
    }
  }

  $Operation,
  $Branch,
  $Detached,
  $DirWarning,
  $LastTag
}

# dirty count {{{4

function pwsh_git_prompt_dirty {
  (git diff --name-only --diff-filter=u 2>$null | Measure-Object -Line).Lines
}

# staged count {{{4

function pwsh_git_prompt_staged {
  (git diff --staged --name-only 2>$null | Measure-Object -Line).Lines
}

# unmerged count {{{4

function pwsh_git_prompt_unmerged {
  (git diff --name-only --diff-filter=U 2>$null | Measure-Object -Line).Lines
}

# untracked count {{{4

function pwsh_git_prompt_untracked {
  (git ls-files --others --exclude-standard -- `
       (git rev-parse --show-toplevel) 2>$null | Measure-Object -Line).Lines
}

# stashed count {{{4

function pwsh_git_prompt_stashed {
  git rev-list --walk-reflogs --count refs/stash 2>$null
}

# upstream counts {{{4

function pwsh_git_prompt_upstream {
  -split (git rev-list --count --left-right --cherry-mark '@{upstream}...HEAD' `
          2>$null)
}

# main git prompt piece {{{4

function pwsh_git_prompt {
  # First check if git is installed. If not exit with error.
  if (!(Get-Command git)) {
    throw 'Git is not installed'
  }

  $RepoInfo = (pwsh_git_prompt_repo_info)

  # Check if inside a git repository and exit silently, if not.
  if (!$RepoInfo) {
    return
  }

  # Get some ref information.
  $StateInfo  = (pwsh_git_prompt_state_info @RepoInfo)
  $Operation  = $StateInfo[0]
  $Branch     = $StateInfo[1]
  $Detached   = $StateInfo[2]
  $DirWarning = $StateInfo[3]
  $LastTag    = $StateInfo[4]

  # Prepare some variables
  $Dirty     = (pwsh_git_prompt_dirty)
  $Staged    = (pwsh_git_prompt_staged)
  $Unmerged  = (pwsh_git_prompt_unmerged)
  $Stashes   = (pwsh_git_prompt_stashed)
  $Untracked = (pwsh_git_prompt_untracked)

  $UpstreamInfo = (pwsh_git_prompt_upstream)
  if ($UpstreamInfo) {
    $Behind = $UpstreamInfo[0]
    $Ahead = $UpstreamInfo[1]
    $CherryEqual = $UpstreamInfo[2]
  }

  $OutString = "$(Pr_Fg($Grey50))$(Pr_Bg($Grey700)) "

  if ($DirWarning) {
    $OutString += "$(Pr_Fg($Orange500))"
    $OutString += "$DirWarning"
    $OutString += "$(Pr_Fg($Grey300)) $SeparatorChar2 $(Pr_Fg($Grey50))"
  }

  if ($Operation) {
    $OutString += "$(Pr_Fg($Orange500))"
    $OutString += "$Operation"
    $OutString += "$(Pr_Fg($Grey300)) $SeparatorChar2 $(Pr_Fg($Grey50))"
  }

  if ($LastTag) {
    $OutString += "$(Pr_Fg($Yellow600))"
    $OutString += "$LastTag"
    $OutString += "$(Pr_Fg($Grey300)) $SeparatorChar2 $(Pr_Fg($Grey50))"
  }

  if ($Branch) {
    if ($Detached) {
      $OutString += "$(Pr_Fg($RedA100))"
    }
    $OutString += Pr_MinifyPath($Branch)
    if ($Detached) {
      $OutString += "$(Pr_Fg($Grey50))"
    }
    $OutString += ' '
  }

  if ($Behind -and $Behind -ne 0) {
    $OutString += "$(Pr_Fg($LightBlueA100))↓$Behind$(Pr_Fg($Grey50)) "
  }

  if ($Ahead -and $Ahead -ne 0) {
    $OutString += "$(Pr_Fg($LightBlueA100))↑$Ahead$(Pr_Fg($Grey50)) "
  }

  if ($CherryEqual -and $CherryEqual -ne 0) {
    $OutString += "$(Pr_Fg($LightBlueA100))C$CherryEqual$(Pr_Fg($Grey50)) "
  }

  if (($Staged -and $Staged -ne 0) -or `
      ($Dirty -and $Dirty -ne 0) -or `
      ($Stashes -and $Stashes -ne 0) -or `
      ($Untracked -and $Untracked -ne 0)) {
    $OutString += "$(Pr_Fg($Grey300))$SeparatorChar2$(Pr_Fg($Grey50)) "
  }

  if ($Stashes -and $Stashes -ne 0) {
    $OutString += "$(Pr_Fg($Yellow500))⚑ $Stashes$(Pr_Fg($Grey50)) "
  }

  if ($Staged -and $Staged -ne 0) {
    $OutString += "$(Pr_Fg($GreenA700))● $Staged$(Pr_Fg($Grey50)) "
  }

  if ($Unmerged -and $Unmerged -ne 0) {
    $OutString += "$(Pr_Fg($Red300))✖ $Unmerged$(Pr_Fg($Grey50)) "
  }

  if ($Dirty -and $Dirty -ne 0) {
    $OutString += "$(Pr_Fg($RedA100))✚ $Dirty$(Pr_Fg($Grey50)) "
  }

  if ($Untracked -and $Untracked -ne 0) {
    $OutString += "$(Pr_Fg($RedA200))… $Untracked$(Pr_Fg($Grey50)) "
  }

  $OutString
}

# powershell prompt function {{{3

function Prompt {
  # get the status first, so it is not overwritten by anything in the prompt
  # function
  $LastSuccess = $?
  $LastStatus = $LastExitCode

  # separator escape sequence variables
  $SepFg = "$(Pr_Fg_Default)"
  $SepBg = "$(Pr_Bg_Default)"

  $OutString = ''

  # set the starting colors
  $OutString += "$(Pr_Fg($Grey50))$(Pr_Bg($Grey400))"

  # add the current working directory
  $OutString += " $(Pr_MinifyPath((Get-Location).Path)) "
  $SepFg = $Grey400

  $GitStatus = (pwsh_git_prompt)
  if ($GitStatus) {
    $SepBg = $Grey700
    $OutString += "$(Pr_Fg($SepFg))$(Pr_Bg($SepBg))$SeparatorChar"
    $OutString += "$(Pr_Fg($Grey50))"
    $OutString += $GitStatus
    $SepFg = $Grey700
  }

  # add the last status
  if (!$LastSuccess) {
    $SepBg = $Red500
    $OutString += "$(Pr_Fg($SepFg))$(Pr_Bg($SepBg))$SeparatorChar"
    $OutString += "$(Pr_Fg($Grey50))"
    if ($LastStatus) {
      $OutString += " $LastStatus "
    }
    $SepFg = $Red500
  }

  # add a seperator transition for the "PromptText" option
  $SepBg = $Grey700
  $OutString += "$(Pr_Fg($SepFg))$(Pr_Bg($SepBg))$SeparatorChar"
  $SepFg = $Grey700

  # add final separator
  $OutString += "$(Pr_Fg($SepFg))$(Pr_Bg_Default)$SeparatorChar"

  # reset colors and add some padding
  $OutString += "$(Pr_Reset) "

  Write-Output $OutString
}

# Aliases {{{1

Set-Alias -Name ll -Value Get-ChildItem

# Clean up {{{1

# Remove-Item 'Function:Pr_*'

# Chocolatey {{{1

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
