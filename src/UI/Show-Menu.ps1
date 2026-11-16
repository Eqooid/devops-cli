function Resolve-MenuKey {
    param([ConsoleKeyInfo]$Key, [int]$Count, [int]$Index = 0)

    $choice = -1
    if ($Count -le 0) { return [pscustomobject]@{ Index = 0; Choice = 0 } }
    if ($Index -lt 0 -or $Index -ge $Count) { throw 'Menu index is out of range.' }
    if ($Key.Key -eq [ConsoleKey]::UpArrow) { $Index = ($Index + $Count - 1) % $Count }
    elseif ($Key.Key -eq [ConsoleKey]::DownArrow) { $Index = ($Index + 1) % $Count }
    elseif ($Key.Key -eq [ConsoleKey]::Enter) { $choice = $Index + 1 }
    elseif ($Key.Key -eq [ConsoleKey]::Escape -or $Key.KeyChar -eq '0') { $choice = 0 }
    elseif ($Count -le 9 -and [string]$Key.KeyChar -cmatch '^[1-9]$') {
        $number = [int]::Parse([string]$Key.KeyChar)
        if ($number -le $Count) { $choice = $number }
    }
    [pscustomobject]@{ Index = $Index; Choice = $choice }
}

function Show-Menu {
    <# Returns a one-based item number, or zero for Back/Exit. #>
    param(
        [string]$Title,
        [AllowEmptyCollection()][string[]]$Items = @(),
        [string[]]$Descriptions = @(),
        [switch]$Root
    )

    if ($Items.Count -eq 0) { return 0 }
    if ($Host.Name -ne 'ConsoleHost' -or [Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        throw 'Interactive menus require a console terminal with unredirected input/output. Run devops.ps1 in Windows Terminal or a console PowerShell window; use ssh setup for the text workflow.'
    }

    $cursorVisible = [Console]::CursorVisible
    try {
        [Console]::CursorVisible = $false
        Clear-Host
        $index = 0
        $redraw = $true
        $lastWidth = 0
        $lastHeight = 0
        while ($true) {
            $width = [Console]::WindowWidth
            $height = [Console]::WindowHeight
            if ($width -lt 25 -or $height -lt 12) { throw 'Enlarge the terminal to at least 25 columns and 12 rows.' }
            if ($redraw -or $width -ne $lastWidth -or $height -ne $lastHeight) {
                $visible = [Math]::Min($Items.Count, $height - 9)
                $first = [Math]::Min([Math]::Max(0, $index - $visible + 1), $Items.Count - $visible)
                $lines = @(' DEVOPS CLI', ' Linux Management Console', (' ' + ('-' * ($width - 3))), " $Title", '')
                for ($i = $first; $i -lt $first + $visible; $i++) {
                    $marker = ' '
                    if ($i -eq $index) { $marker = '>' }
                    $label = " $marker [$($i + 1)] $($Items[$i])"
                    if ($width -ge 80 -and $i -lt $Descriptions.Count) { $label += " - $($Descriptions[$i])" }
                    $lines += $label
                }
                $back = 'Back'
                if ($Root) { $back = 'Exit' }
                $lines += @('', " Up/Down | Enter | $($index + 1)/$($Items.Count)", " Esc/0 $back")
                if ($Items.Count -le 9) { $lines[-1] += ' | 1-9 Select' }
                else { $lines[-1] += ' | Arrows only' }
                for ($row = 0; $row -lt $height - 1; $row++) {
                    $line = ''
                    if ($row -lt $lines.Count) { $line = $lines[$row] }
                    # Keep one spare column so output never wraps or scrolls the menu.
                    $line = ($line -replace '[\x00-\x1f\x7f]', ' ')
                    if ($line.Length -gt $width - 1) { $line = $line.Substring(0, $width - 4) + '...' }
                    $color = 'Gray'
                    if ($row -eq 0 -or $row -eq 3 -or $line.StartsWith(' >')) { $color = 'Cyan' }
                    [Console]::SetCursorPosition(0, $row)
                    Write-Host $line.PadRight($width - 1) -NoNewline -ForegroundColor $color
                }
                $lastWidth = $width
                $lastHeight = $height
                $redraw = $false
            }
            # Poll only for keys/resizes; there is no animation or periodic repaint.
            if (-not [Console]::KeyAvailable) { Start-Sleep -Milliseconds 40; continue }
            $state = Resolve-MenuKey -Key ([Console]::ReadKey($true)) -Count $Items.Count -Index $index
            if ($state.Choice -ge 0) { return $state.Choice }
            $redraw = $state.Index -ne $index
            $index = $state.Index
        }
    }
    finally {
        [Console]::CursorVisible = $cursorVisible
        # Do not leak held/repeated menu keys into the next text prompt.
        while ([Console]::KeyAvailable) { $null = [Console]::ReadKey($true) }
        [Console]::SetCursorPosition(0, [Math]::Max(0, [Console]::WindowHeight - 1))
        Write-Host ''
    }
}
