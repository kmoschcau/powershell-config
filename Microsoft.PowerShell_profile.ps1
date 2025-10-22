# vim: foldmethod=marker
$NonInteractive = [Environment]::GetCommandLineArgs() | Where-Object {
  $_ -Like '-NonI*'
}

# options {{{

# PSReadLine {{{

# Change the edit mode to Vi
Set-PSReadLineOption -EditMode Vi

# Set the indicator style for Vi normal mode
function OnViModeChange {
    if ($args[0] -eq 'Command') {
        # Set the cursor to a blinking block and the cursor color.
        Write-Host -NoNewLine "`e[1 q`e]12;rgb:01/c4/c4`e\"
    } else {
        # Set the cursor to a blinking line and the cursor color.
        Write-Host -NoNewLine "`e[5 q`e]12;rgb:00/7f/bc`e\"
    }
}
Set-PSReadLineOption `
  -ViModeIndicator Script `
  -ViModeChangeHandler $Function:OnViModeChange

function IsVirtualTerminalProcessingEnabled {
  $MethodDefinitions = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
'@
  $Kernel32 = Add-Type -MemberDefinition $MethodDefinitions -Name 'Kernel32' -Namespace 'Win32' -PassThru
  $hConsoleHandle = $Kernel32::GetStdHandle(-11) # STD_OUTPUT_HANDLE
  $mode = 0
  $Kernel32::GetConsoleMode($hConsoleHandle, [ref]$mode) >$null
  if ($mode -band 0x0004) { # 0x0004 ENABLE_VIRTUAL_TERMINAL_PROCESSING
    return $true
  }
  return $false
}

function CanUsePredictionSource {
  return (! [System.Console]::IsOutputRedirected) -And (IsVirtualTerminalProcessingEnabled)
}

# Enable auto suggestions like in fish
try {
  if ([Environment]::UserInteractive -And -Not $NonInteractive -And (CanUsePredictionSource)) {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
  }
} catch [System.Management.Automation.ParameterBindingException] {
  # This means we deal with a version where this is not supported, just ignore
  # it.
}

# }}}

# KeyHandlers {{{

Set-PSReadlineKeyHandler `
  -ViMode Insert -Chord Ctrl+w -Function ViBackwardDeleteGlob

Set-PSReadlineKeyHandler `
  -ViMode Insert -Chord Tab -Function MenuComplete

Set-PSReadlineKeyHandler `
  -ViMode Insert -Chord Ctrl+RightArrow -Function AcceptNextSuggestionWord

# }}}}}}}}}

# helper functions {{{

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

# }}}

# theming {{{

# helper functions {{{

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

  "`e[38;$(Pr_CssColorToSGRParameters($CssColor))m"
}

function Pr_Bg {
  Param ([string]$CssColor)

  "`e[48;$(Pr_CssColorToSGRParameters($CssColor))m"
}

function Pr_Bg_Default {
  "`e[49m"
}

function Pr_Bold {
  "`e[1m"
}

function Pr_Italic {
  "`e[3m"
}

# }}}

# color definitions {{{

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

# }}}

# syntax colors {{{

Set-PSReadLineOption -Colors @{
  Command                = Pr_Fg($Teal500)
  Comment                = Pr_Fg($Grey500)
  ContinuationPrompt     = Pr_Fg($Grey400)
  Default                = Pr_Fg($Grey700)
  Emphasis               = Pr_Bg($Yellow500)
  Error                  = "$(Pr_Fg($Grey50))$(Pr_Bg($Red500))"
  InlinePrediction       = Pr_Fg($Grey500)
  ListPrediction         = Pr_Fg($Grey500)
  ListPredictionSelected = Pr_Bg($Cyan100)
  Keyword                = "$(Pr_Bold)$(Pr_Fg($Orange600))"
  Member                 = Pr_Fg($Blue500)
  Number                 = "$(Pr_Fg($Blue600))$(Pr_Bg($Blue50))"
  Operator               = Pr_Fg($Orange600)
  Parameter              = "$(Pr_Italic)$(Pr_Fg($Orange500))"
  Selection              = Pr_Bg($Cyan100)
  String                 = "$(Pr_Fg($Green600))$(Pr_Bg($Green50))"
  Type                   = Pr_Fg($Green500)
  Variable               = Pr_Fg($LightGreen500)
}

# }}}

# host private data colors {{{

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

# }}}}}}

# Prompt {{{

# Glyph compat setup {{{

if ($env:TERM -match '^xterm-256color' -or `
    $env:WT_SESSION -and `
    $PSVersionTable.PSVersion.Major -ge 6) {
  $AheadGlyph = '↑'
  $BehindGlyph = '↓'
  $CherryGlyph = '🍒'
  $DirtyGlyph = '󰄱 '
  $SeparatorGlyph  = ''
  $SeparatorGlyph2 = ''
  $StagedGlyph = ' '
  $StashGlyph = '⚑ '
  $UnmergedGlyph = ' '
  $UntrackedGlyph = ' '
} else {
  $AheadGlyph = '^'
  $BehindGlyph = 'v'
  $CherryGlyph = 'C'
  $DirtyGlyph = 'D'
  $SeparatorGlyph  = '>'
  $SeparatorGlyph2 = '>'
  $StagedGlyph = 'S'
  $StashGlyph = 'St'
  $UnmergedGlyph = 'M'
  $UntrackedGlyph = '?'
}

# }}}

# Continuation {{{

Set-PSReadLineOption -ContinuationPrompt "$SeparatorGlyph"

# }}}

# Syntax error indicator {{{

# Set the text to change color in the prompt on syntax error.
Set-PSReadLineOption -PromptText "$SeparatorGlyph "

# }}}

# customize the prompt {{{

# git prompt functions {{{

# repo info {{{

function pwsh_git_prompt_repo_info {
  $Result =
    (git rev-parse --git-dir --is-inside-git-dir --is-bare-repository 2>$null)

  if ($Result) {
    $Result[0],
    ($Result[1] -eq 'true'),
    ($Result[2] -eq 'true')
  }
}

# }}}

# state info {{{

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

  # If there are steps and total, add it do the operation.
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

# }}}

# dirty count {{{

function pwsh_git_prompt_dirty {
  (git diff --name-only --diff-filter=u 2>$null | Measure-Object -Line).Lines
}

# }}}

# staged count {{{

function pwsh_git_prompt_staged {
  (git diff --staged --name-only 2>$null | Measure-Object -Line).Lines
}

# }}}

# unmerged count {{{

function pwsh_git_prompt_unmerged {
  (git diff --name-only --diff-filter=U 2>$null | Measure-Object -Line).Lines
}

# }}}

# untracked count {{{

function pwsh_git_prompt_untracked {
  (git ls-files --others --exclude-standard -- `
       (git rev-parse --show-toplevel) 2>$null | Measure-Object -Line).Lines
}

# }}}

# stashed count {{{

function pwsh_git_prompt_stashed {
  git rev-list --walk-reflogs --count refs/stash 2>$null
}

# }}}

# upstream counts {{{

function pwsh_git_prompt_upstream {
  -split (git rev-list --count --left-right --cherry-mark '@{upstream}...HEAD' `
          2>$null)
}

# }}}

# main git prompt piece {{{

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

  # Prepare some variables.
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
    $OutString += "$(Pr_Fg($Grey300)) $SeparatorGlyph2 $(Pr_Fg($Grey50))"
  }

  if ($Operation) {
    $OutString += "$(Pr_Fg($Orange500))"
    $OutString += "$Operation"
    $OutString += "$(Pr_Fg($Grey300)) $SeparatorGlyph2 $(Pr_Fg($Grey50))"
  }

  if ($LastTag) {
    $OutString += "$(Pr_Fg($Yellow600))"
    $OutString += "$LastTag"
    $OutString += "$(Pr_Fg($Grey300)) $SeparatorGlyph2 $(Pr_Fg($Grey50))"
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
    $OutString += `
      "$(Pr_Fg($LightBlueA100))$BehindGlyph$Behind$(Pr_Fg($Grey50)) "
  }

  if ($Ahead -and $Ahead -ne 0) {
    $OutString += "$(Pr_Fg($LightBlueA100))$AheadGlyph$Ahead$(Pr_Fg($Grey50)) "
  }

  if ($CherryEqual -and $CherryEqual -ne 0) {
    $OutString += `
      "$(Pr_Fg($LightBlueA100))$CherryGlyph$CherryEqual$(Pr_Fg($Grey50)) "
  }

  if (($Staged -and $Staged -ne 0) -or `
      ($Dirty -and $Dirty -ne 0) -or `
      ($Stashes -and $Stashes -ne 0) -or `
      ($Untracked -and $Untracked -ne 0)) {
    $OutString += "$(Pr_Fg($Grey300))$SeparatorGlyph2$(Pr_Fg($Grey50)) "
  }

  if ($Stashes -and $Stashes -ne 0) {
    $OutString += "$(Pr_Fg($Yellow500))$StashGlyph$Stashes$(Pr_Fg($Grey50)) "
  }

  if ($Staged -and $Staged -ne 0) {
    $OutString += "$(Pr_Fg($GreenA700))$StagedGlyph$Staged$(Pr_Fg($Grey50)) "
  }

  if ($Unmerged -and $Unmerged -ne 0) {
    $OutString += "$(Pr_Fg($Red300))$UnmergedGlyph$Unmerged$(Pr_Fg($Grey50)) "
  }

  if ($Dirty -and $Dirty -ne 0) {
    $OutString += "$(Pr_Fg($RedA100))$DirtyGlyph$Dirty$(Pr_Fg($Grey50)) "
  }

  if ($Untracked -and $Untracked -ne 0) {
    $OutString += `
      "$(Pr_Fg($RedA200))$UntrackedGlyph$Untracked$(Pr_Fg($Grey50)) "
  }

  $OutString
}

# }}}}}}

# powershell prompt function {{{

$Global:__LastHistoryId = -1

# Get the last status code in a more unixy manner.
function Global:__Terminal-Get-LastExitCode {
  if ($? -eq $True) {
    return 0
  }

  $LastHistoryEntry = $(Get-History -Count 1)
  $IsPowerShellError = `
    $Error[0].InvocationInfo.HistoryId -eq $LastHistoryEntry.Id
  if ($IsPowershellError) {
    return -1
  }

  return $LastExitCode
}

function Prompt {
  $LastStatus = $(__Terminal-Get-LastExitCode)
  $Location = $executionContext.SessionState.Path.CurrentLocation

  $OutString = ''

  $LastHistoryEntry = $(Get-History -Count 1)

  # Send the operating system command (OSC) for command finished.
  # ("FTCS_COMMAND_FINISHED")
  if ($Global:__LastHistoryId -ne -1) {
    if ($LastHistoryEntry.Id -eq $Global:__LastHistoryId) {
      $OutString += "`e]133;D`e\"
    } else {
      $OutString += "`e]133;D;$LastStatus`e\"
    }
  }

  # Set the cursor to a blinking line, because we always start in insert mode.
  $OutString += "`e[5 q`e]12;rgb:00/7f/bc`e\"

  # Send OSC for current working directory.
  if ($Location.Provider.Name -eq "FileSystem") {
    $OutString += "`e]9;9;`"$($Location.ProviderPath)`"`e\"
  }

  # Set the separator escape sequence variables.
  $SepFg = "`e[39m"
  $SepBg = "$(Pr_Bg_Default)"

  # Send OSC for prompt start.
  # ("FTCS_PROMPT")
  $OutString += "`e]133;A`e\"

  # Set the starting colors.
  $OutString += "$(Pr_Fg($Grey50))$(Pr_Bg($Grey400))"

  # Add the current working directory.
  $OutString += " $(Pr_MinifyPath($Location.ProviderPath)) "
  $SepFg = $Grey400

  # Add the git prompt.
  $GitStatus = (pwsh_git_prompt)
  if ($GitStatus) {
    $SepBg = $Grey700
    $OutString += "$(Pr_Fg($SepFg))$(Pr_Bg($SepBg))$SeparatorGlyph"
    $OutString += "$(Pr_Fg($Grey50))"
    $OutString += $GitStatus
    $SepFg = $Grey700
  }

  # Add the last status.
  if ($LastStatus -ne 0) {
    $SepBg = $Red500
    $OutString += "$(Pr_Fg($SepFg))$(Pr_Bg($SepBg))$SeparatorGlyph"
    $OutString += "$(Pr_Fg($Grey50))"
    $OutString += " $LastStatus "
    $SepFg = $Red500
  }

  # Add a separator transition for the "PromptText" option.
  $SepBg = $Grey700
  $OutString += "$(Pr_Fg($SepFg))$(Pr_Bg($SepBg))$SeparatorGlyph"
  $SepFg = $Grey700

  # Add the final separator.
  $OutString += "$(Pr_Fg($SepFg))$(Pr_Bg_Default)$SeparatorGlyph"

  # Reset the colors and add some padding.
  $OutString += "`e[0m "

  # Send OSC for prompt end/command start.
  # ("FTCS_COMMAND_START")
  $OutString += "`e]133;B`e\"

  return $OutString
}

# }}}}}}}}}

# Aliases {{{

Set-Alias -Name ll -Value Get-ChildItem

# }}}

# Clean up {{{

# Remove-Item 'Function:Pr_*'

# }}}

# Completions {{{

# az CLI {{{

Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
  param($commandName, $wordToComplete, $cursorPosition)
  $completion_file = New-TemporaryFile
  $env:ARGCOMPLETE_USE_TEMPFILES = 1
  $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
  $env:COMP_LINE = $wordToComplete
  $env:COMP_POINT = $cursorPosition
  $env:_ARGCOMPLETE = 1
  $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
  $env:_ARGCOMPLETE_IFS = "`n"
  $env:_ARGCOMPLETE_SHELL = "powershell"
  az 2>&1 | Out-Null
  Get-Content $completion_file | Sort-Object | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
  }
  Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}

# }}}

# dotnet CLI {{{

Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object {
    [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
  }
}

# }}}

# gitleaks {{{

function __gitleaks_debug {
  if ($env:BASH_COMP_DEBUG_FILE) {
    "$args" | Out-File -Append -FilePath "$env:BASH_COMP_DEBUG_FILE"
  }
}

filter __gitleaks_escapeStringWithSpecialChars {
  $_ -replace '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&','`$&'
}

Register-ArgumentCompleter -CommandName 'gitleaks' -ScriptBlock {
param(
    $WordToComplete,
    $CommandAst,
    $CursorPosition
  )

  # Get the current command line and convert into a string
  $Command = $CommandAst.CommandElements
  $Command = "$Command"

  __gitleaks_debug ""
  __gitleaks_debug "========= starting completion logic =========="
  __gitleaks_debug "WordToComplete: $WordToComplete Command: $Command CursorPosition: $CursorPosition"

  # The user could have moved the cursor backwards on the command-line.
  # We need to trigger completion from the $CursorPosition location, so we need
  # to truncate the command-line ($Command) up to the $CursorPosition location.
  # Make sure the $Command is longer then the $CursorPosition before we truncate.
  # This happens because the $Command does not include the last space.
  if ($Command.Length -gt $CursorPosition) {
    $Command=$Command.Substring(0,$CursorPosition)
  }
  __gitleaks_debug "Truncated command: $Command"

  $ShellCompDirectiveError=1
  $ShellCompDirectiveNoSpace=2
  $ShellCompDirectiveNoFileComp=4
  $ShellCompDirectiveFilterFileExt=8
  $ShellCompDirectiveFilterDirs=16

  # Prepare the command to request completions for the program.
  # Split the command at the first space to separate the program and arguments.
  $Program,$Arguments = $Command.Split(" ",2)
  $RequestComp="$Program __complete $Arguments"
  __gitleaks_debug "RequestComp: $RequestComp"

  # we cannot use $WordToComplete because it
  # has the wrong values if the cursor was moved
  # so use the last argument
  if ($WordToComplete -ne "" ) {
    $WordToComplete = $Arguments.Split(" ")[-1]
  }
  __gitleaks_debug "New WordToComplete: $WordToComplete"


  # Check for flag with equal sign
  $IsEqualFlag = ($WordToComplete -Like "--*=*" )
  if ( $IsEqualFlag ) {
    __gitleaks_debug "Completing equal sign flag"
    # Remove the flag part
    $Flag,$WordToComplete = $WordToComplete.Split("=",2)
  }

  if ( $WordToComplete -eq "" -And ( -Not $IsEqualFlag )) {
    # If the last parameter is complete (there is a space following it)
    # We add an extra empty parameter so we can indicate this to the go method.
    __gitleaks_debug "Adding extra empty parameter"
    # We need to use `"`" to pass an empty argument a "" or '' does not work!!!
    $RequestComp="$RequestComp" + ' `"`"'
  }

  __gitleaks_debug "Calling $RequestComp"
  #call the command store the output in $out and redirect stderr and stdout to null
  # $Out is an array contains each line per element
  Invoke-Expression -OutVariable out "$RequestComp" 2>&1 | Out-Null


  # get directive from last line
  [int]$Directive = $Out[-1].TrimStart(':')
  if ($Directive -eq "") {
    # There is no directive specified
    $Directive = 0
  }
  __gitleaks_debug "The completion directive is: $Directive"

  # remove directive (last element) from out
  $Out = $Out | Where-Object { $_ -ne $Out[-1] }
  __gitleaks_debug "The completions are: $Out"

  if (($Directive -band $ShellCompDirectiveError) -ne 0 ) {
    # Error code.  No completion.
    __gitleaks_debug "Received error from custom completion go code"
    return
  }

  $Longest = 0
  $Values = $Out | ForEach-Object {
    #Split the output in name and description
    $Name, $Description = $_.Split("`t",2)
    __gitleaks_debug "Name: $Name Description: $Description"

    # Look for the longest completion so that we can format things nicely
    if ($Longest -lt $Name.Length) {
      $Longest = $Name.Length
    }

    # Set the description to a one space string if there is none set.
    # This is needed because the CompletionResult does not accept an empty string as argument
    if (-Not $Description) {
      $Description = " "
    }
    @{Name="$Name";Description="$Description"}
  }


  $Space = " "
  if (($Directive -band $ShellCompDirectiveNoSpace) -ne 0 ) {
    # remove the space here
    __gitleaks_debug "ShellCompDirectiveNoSpace is called"
    $Space = ""
  }

  if ((($Directive -band $ShellCompDirectiveFilterFileExt) -ne 0 ) -or
  (($Directive -band $ShellCompDirectiveFilterDirs) -ne 0 ))  {
    __gitleaks_debug "ShellCompDirectiveFilterFileExt ShellCompDirectiveFilterDirs are not supported"

    # return here to prevent the completion of the extensions
    return
  }

  $Values = $Values | Where-Object {
    # filter the result
    $_.Name -like "$WordToComplete*"

    # Join the flag back if we have an equal sign flag
    if ( $IsEqualFlag ) {
      __gitleaks_debug "Join the equal sign flag back to the completion value"
      $_.Name = $Flag + "=" + $_.Name
    }
  }

  if (($Directive -band $ShellCompDirectiveNoFileComp) -ne 0 ) {
    __gitleaks_debug "ShellCompDirectiveNoFileComp is called"

    if ($Values.Length -eq 0) {
      # Just print an empty string here so the
      # shell does not start to complete paths.
      # We cannot use CompletionResult here because
      # it does not accept an empty string as argument.
      ""
      return
    }
  }

  # Get the current mode
  $Mode = (Get-PSReadLineKeyHandler | Where-Object {$_.Key -eq "Tab" }).Function
  __gitleaks_debug "Mode: $Mode"

  $Values | ForEach-Object {

    # store temporary because switch will overwrite $_
    $comp = $_

    # PowerShell supports three different completion modes
    # - TabCompleteNext (default windows style - on each key press the next option is displayed)
    # - Complete (works like bash)
    # - MenuComplete (works like zsh)
    # You set the mode with Set-PSReadLineKeyHandler -Key Tab -Function <mode>

    # CompletionResult Arguments:
    # 1) CompletionText text to be used as the auto completion result
    # 2) ListItemText   text to be displayed in the suggestion list
    # 3) ResultType     type of completion result
    # 4) ToolTip        text for the tooltip with details about the object

    switch ($Mode) {

      # bash like
      "Complete" {

        if ($Values.Length -eq 1) {
          __gitleaks_debug "Only one completion left"

          # insert space after value
          [System.Management.Automation.CompletionResult]::new($($comp.Name | __gitleaks_escapeStringWithSpecialChars) + $Space, "$($comp.Name)", 'ParameterValue', "$($comp.Description)")

        } else {
          # Add the proper number of spaces to align the descriptions
          while($comp.Name.Length -lt $Longest) {
            $comp.Name = $comp.Name + " "
          }

          # Check for empty description and only add parentheses if needed
          if ($($comp.Description) -eq " " ) {
            $Description = ""
          } else {
            $Description = "  ($($comp.Description))"
          }

          [System.Management.Automation.CompletionResult]::new("$($comp.Name)$Description", "$($comp.Name)$Description", 'ParameterValue', "$($comp.Description)")
        }
      }

      # zsh like
      "MenuComplete" {
        # insert space after value
        # MenuComplete will automatically show the ToolTip of
        # the highlighted value at the bottom of the suggestions.
        [System.Management.Automation.CompletionResult]::new($($comp.Name | __gitleaks_escapeStringWithSpecialChars) + $Space, "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
      }

      # TabCompleteNext and in case we get something unknown
      Default {
        # Like MenuComplete but we don't want to add a space here because
        # the user need to press space anyway to get the completion.
        # Description will not be shown because thats not possible with TabCompleteNext
        [System.Management.Automation.CompletionResult]::new($($comp.Name | __gitleaks_escapeStringWithSpecialChars), "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
      }
    }

  }
}

# }}}

# winget {{{

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# }}}}}}

# Utility functions {{{

function SetUpDotnetWatch {
  $env:DOTNET_USE_POLLING_FILE_WATCHER = "true"
  $env:DOTNET_WATCH_RESTART_ON_RUDE_EDIT = "true"
  $env:DOTNET_WATCH_SUPPRESS_LAUNCH_BROWSER = "true"
  $env:DOTNET_WATCH_SUPPRESS_STATIC_FILE_HANDLING = "true"
}

# }}}

# Chocolatey {{{

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# }}}

# Starship {{{

Invoke-Expression (&starship init powershell)

# }}}

# Opam {{{

(& opam env --switch=default) -split '\r?\n' | ForEach-Object { Invoke-Expression $_ }

# }}}

# Yazi {{{

function y {
  $tmp = [System.IO.Path]::GetTempFileName()
  yazi $args --cwd-file=$tmp
  $cwd = Get-Content -Path $tmp
  if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
    Set-Location -LiteralPath $cwd
  }
  Remove-Item -Path $tmp
}

# }}}

# Zoxide {{{

Invoke-Expression (& { (zoxide init powershell | Out-String) })

# }}}
