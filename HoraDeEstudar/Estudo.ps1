Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$ErrorActionPreference='Stop'
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -STA -ExecutionPolicy RemoteSigned -File "'+$PSCommandPath+'"')
    return
}
$mutex=New-Object Threading.Mutex($false,'Global\HoraDeEstudarDesktop')
try{$owner=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owner=$true}
if(!$owner){[Windows.Forms.MessageBox]::Show('O aplicativo ja esta aberto.');return}
$hostsFile=Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$encoding=[Text.Encoding]::GetEncoding(28591)
function Set-Sites($names){
    $old=[IO.File]::ReadAllText($hostsFile,$encoding)
    $new=[regex]::Replace($old,'\r?\n# HoraDeEstudar BEGIN\r?\n[\s\S]*?\r?\n# HoraDeEstudar END\r?\n','')
    if($names.Count){
        $lines=foreach($name in $names){foreach($addr in @($name,"www.$name")){"0.0.0.0 $addr";":: $addr"}}
        $new+="`r`n# HoraDeEstudar BEGIN`r`n"+($lines -join "`r`n")+"`r`n# HoraDeEstudar END`r`n"
    }
    if($new -cne $old){[IO.File]::WriteAllText($hostsFile,$new,$encoding);ipconfig /flushdns | Out-Null}
}
Set-Sites @()
[Windows.Forms.Application]::EnableVisualStyles()
$form=New-Object Windows.Forms.Form
$form.Text='Hora de Estudar'
$form.ClientSize=New-Object Drawing.Size(650,580)
$form.FormBorderStyle='FixedSingle'
$form.MaximizeBox=$false
$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Segoe UI',10)
function Control($type,$caption,$x,$y,$w,$h){
    $c=New-Object "Windows.Forms.$type"
    $c.Text=$caption
    $c.SetBounds($x,$y,$w,$h)
    $form.Controls.Add($c)
    return $c
}
$title=Control Label 'Hora de Estudar' 20 15 610 42
$title.Font=New-Object Drawing.Font('Segoe UI',22,[Drawing.FontStyle]::Bold)
$null=Control Label 'Salve seu progresso. Os aplicativos marcados serão fechados durante o estudo.' 20 67 615 35
$null=Control Label 'Aplicativos' 20 105 290 24
$null=Control Label 'Sites' 330 105 290 24
$apps=Control CheckedListBox '' 20 132 295 135
$sites=Control CheckedListBox '' 330 132 295 135
$apps.CheckOnClick=$sites.CheckOnClick=$true
$pick=Control Button 'Escolher .exe' 20 272 165 31
$delApp=Control Button 'Remover' 190 272 124 31
$inputSite=Control TextBox '' 330 273 170 28
$addSite=Control Button 'Adicionar site' 506 270 119 32
$delSite=Control Button 'Remover site' 506 307 119 30
$timed=Control RadioButton 'Cronômetro' 20 351 120 28
$minutes=Control NumericUpDown '' 142 350 68 28
$minutes.Minimum=1
$minutes.Maximum=1440
$minutes.Value=25
$null=Control Label 'minutos' 218 354 78 26
$manual=Control RadioButton 'Até eu decidir parar' 330 351 280 28
$timed.Checked=$true
$null=Control Label 'Senha desta sessão' 20 390 145 25
$key=Control TextBox '' 170 387 130 27
$null=Control Label 'Repita a senha' 330 390 130 25
$repeat=Control TextBox '' 470 387 155 27
$key.UseSystemPasswordChar=$repeat.UseSystemPasswordChar=$true
$null=Control Label 'Descanso após o estudo' 20 432 180 25
$rest=Control NumericUpDown '' 210 428 68 28
$rest.Minimum=1
$rest.Maximum=240
$rest.Value=5
$null=Control Label 'minutos' 290 432 90 25
$status=Control Label 'Pronto para começar' 20 475 605 28
$button=Control Button 'Iniciar estudo' 20 515 605 43
$button.BackColor=[Drawing.Color]::FromArgb(24,96,75)
$button.ForeColor=[Drawing.Color]::White
$config=Join-Path $env:LOCALAPPDATA 'HoraDeEstudar-lista.json'
function Save-List{
    $rows=@(foreach($list in @($apps,$sites)){for($i=0;$i -lt $list.Items.Count;$i++){
        @{app=($list -eq $apps);name=$list.Items[$i];selected=$list.GetItemChecked($i)}
    }})
    [IO.File]::WriteAllText($config,(ConvertTo-Json -InputObject $rows))
}
if(Test-Path $config){
    foreach($row in (Get-Content -Raw -Encoding UTF8 $config | ConvertFrom-Json)){
        $list=if($row.app){,$apps}else{,$sites}
        [void]$list.Items.Add([string]$row.name,[bool]$row.selected)
    }
}else{
    foreach($n in 'RobloxPlayerBeta','Discord'){[void]$apps.Items.Add($n,$true)}
    foreach($n in 'youtube.com','discord.com','roblox.com'){[void]$sites.Items.Add($n,$true)}
}
$pick.Add_Click({
    $dialog=New-Object Windows.Forms.OpenFileDialog
    $dialog.Filter='Aplicativos (*.exe)|*.exe'
    if($dialog.ShowDialog() -eq 'OK'){
        $n=[IO.Path]::GetFileNameWithoutExtension($dialog.FileName)
        if($n -eq [Diagnostics.Process]::GetCurrentProcess().ProcessName -or $dialog.FileName.StartsWith("$env:SystemRoot\",[StringComparison]::OrdinalIgnoreCase) -or $n -in 'powershell','pwsh','explorer'){[Windows.Forms.MessageBox]::Show('Escolha um aplicativo de usuário.')}
        elseif(!$apps.Items.Contains($n)){[void]$apps.Items.Add($n,$true)}
    }
    $dialog.Dispose()
})
$delApp.Add_Click({if($apps.SelectedIndex -ge 0){$apps.Items.RemoveAt($apps.SelectedIndex)}})
$delSite.Add_Click({if($sites.SelectedIndex -ge 0){$sites.Items.RemoveAt($sites.SelectedIndex)}})
$addSite.Add_Click({
    $n=($inputSite.Text.Trim().ToLowerInvariant() -replace '^https?://','' -split '[/#?]')[0] -replace '^www\.',''
    if($n -notmatch '^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$'){[Windows.Forms.MessageBox]::Show('Digite um domínio, como youtube.com.');return}
    if(!$sites.Items.Contains($n)){[void]$sites.Items.Add($n,$true)}
    $inputSite.Clear()
})
$clock=New-Object Diagnostics.Stopwatch
$timer=New-Object Windows.Forms.Timer
$timer.Interval=750
$script:phase='idle'
$extend=Control Button 'Continuar descansando (senha)' 328 515 297 43
$extend.Visible=$false
# Two destinations following the left navigation pattern in WinUI Gallery.
$form.ClientSize=New-Object Drawing.Size(830,540)
$form.BackColor=[Drawing.ColorTranslator]::FromHtml('#F8F9F5')
$ink=[Drawing.ColorTranslator]::FromHtml('#193A32')
$form.ForeColor=$ink
$rail=Control Panel '' 0 0 172 540
$rail.BackColor=$ink
$brand=Control Label "Hora de`nestudar" 21 28 145 85
$brand.Parent=$rail
$brand.Font=New-Object Drawing.Font('Segoe UI',20,[Drawing.FontStyle]::Bold)
$brand.ForeColor=[Drawing.Color]::White
$navSession=Control Button 'Sessão' 10 155 151 44
$navBlocks=Control Button 'Bloqueios' 10 207 151 44
foreach($nav in $navSession,$navBlocks){
    $nav.Parent=$rail
    $nav.ForeColor=[Drawing.Color]::White
    $nav.TextAlign='MiddleLeft'
    $nav.Padding=New-Object Windows.Forms.Padding(12,0,0,0)
}
$session=Control Panel '' 172 0 655 540
$blocks=Control Panel '' 172 0 655 540
foreach($c in @($form.Controls)){
    if($c -in @($rail,$session,$blocks)){continue}
    $y=$c.Top
    if($c -eq $title){$c.Parent=$session;$c.Text='Sua sessão';$c.Top=27;continue}
    if($y -ge 67 -and $y -le 307){$c.Parent=$blocks;$c.Top=$y+20;continue}
    $c.Parent=$session
    if($y -ge 350 -and $y -lt 380){$c.Top=$y-215}
    elseif($y -ge 380 -and $y -lt 420){$c.Top=$y-82}
    elseif($y -ge 420 -and $y -lt 455){$c.Top=$y-243}
    elseif($c -eq $status){$c.Top=396}
    elseif($c -eq $button -or $c -eq $extend){$c.Top=444}
}
function Section-Title($parent,$caption,$y,$size){
    $label=Control Label $caption 20 $y 605 42
    $label.Parent=$parent
    $label.Font=New-Object Drawing.Font('Segoe UI',$size,[Drawing.FontStyle]::Bold)
}
Section-Title $blocks 'Bloqueios' 27 22
Section-Title $session 'Tempo de estudo' 87 14
Section-Title $session 'Senha da sessão' 253 14
$blocks.Visible=$false
function Show-Menu($showSession){
    $session.Visible=$showSession
    $blocks.Visible=!$showSession
    $selected=[Drawing.ColorTranslator]::FromHtml('#356551')
    $navSession.BackColor=if($showSession){$selected}else{$ink}
    $navBlocks.BackColor=if($showSession){$ink}else{$selected}
}
$navSession.Add_Click({Show-Menu $true})
$navBlocks.Add_Click({Show-Menu $false})
foreach($group in $rail,$session,$blocks){
    foreach($c in $group.Controls){
        if($c -is [Windows.Forms.Button]){
            $c.FlatStyle='Flat'
            $c.FlatAppearance.BorderSize=0
            $c.Cursor=[Windows.Forms.Cursors]::Hand
            if($group -ne $rail -and $c -ne $button){$c.BackColor=[Drawing.ColorTranslator]::FromHtml('#DFEAE2')}
        }
    }
}
Show-Menu $true
function Confirm-Key{
    $d=New-Object Windows.Forms.Form
    try{
        $d.Text='Digite a senha desta sessão'
        $d.ClientSize=New-Object Drawing.Size(320,105)
        $d.StartPosition='CenterParent'
        $field=New-Object Windows.Forms.TextBox
        $field.UseSystemPasswordChar=$true
        $field.SetBounds(16,17,288,28)
        $ok=New-Object Windows.Forms.Button
        $ok.Text='Confirmar'
        $ok.SetBounds(195,58,110,32)
        $ok.DialogResult='OK'
        $d.Controls.AddRange(@($field,$ok))
        $d.AcceptButton=$ok
        if($d.ShowDialog($form) -ne 'OK'){return $false}
        if($field.Text -ceq $key.Text){return $true}
        [void][Windows.Forms.MessageBox]::Show('Senha incorreta.')
        return $false
    }finally{$d.Dispose()}
}
function Set-Editing($enabled){
    foreach($c in @($apps,$sites,$pick,$delApp,$delSite,$addSite,$inputSite,$timed,$manual,$key,$repeat,$rest)){$c.Enabled=$enabled}
    $minutes.Enabled=$enabled -and $timed.Checked
}
$timed.Add_CheckedChanged({$minutes.Enabled=$timed.Checked})
function Start-Focus{
    Set-Sites @($sites.CheckedItems)
    $script:phase='study'
    $extend.Visible=$false
    $button.Width=605
    $button.Text='Começar descanso'
    $clock.Restart()
    Update-Study
}
function Start-Rest{
    Set-Sites @()
    $script:phase='rest'
    $clock.Restart()
    $extend.Visible=$false
    $button.Width=605
    $button.Text='Voltar a estudar'
    Update-Study
}
function Update-Study{
    $t=$clock.Elapsed
    if($script:phase -eq 'rest'){
        $left=[TimeSpan]::FromMinutes([double]$rest.Value)-$t
        if($left.TotalSeconds -le 0){
            [System.Media.SystemSounds]::Exclamation.Play()
            $script:phase='relock'
        }else{
        $status.Text='Descanso   '+$left.ToString('hh\:mm\:ss')+'   •   Aplicativos e sites liberados'
        return
        }
    }
    if($script:phase -eq 'relock'){
        try{
            Set-Sites @($sites.CheckedItems)
            $script:phase='waiting'
            $button.Width=296
            $extend.Visible=$true
            Show-Menu $true
            $form.WindowState='Normal'
            [void]$form.Activate()
        }catch{$status.Text='Reaplicando bloqueio de sites. Nova tentativa em instantes.'}
    }
    if($script:phase -eq 'study'){
    if($timed.Checked){
        $t=[TimeSpan]::FromMinutes([double]$minutes.Value)-$t
        if($t.TotalSeconds -le 0){Start-Rest;return}
    }
    $status.Text=$(if($timed.Checked){'Tempo restante   '}else{'Tempo de estudo   '})+$t.ToString('hh\:mm\:ss')
    }elseif($script:phase -eq 'waiting'){
        $status.Text='Descanso encerrado. Aplicativos e sites marcados estão bloqueados.'
    }
    foreach($n in $apps.CheckedItems){
        foreach($p in [Diagnostics.Process]::GetProcessesByName($n)){
            try{$p.Kill()}catch{if(!$p.HasExited){$status.Text+="   Falha ao fechar $n"}}finally{$p.Dispose()}
        }
    }
}
$timer.Add_Tick({try{Update-Study}catch{$status.Text="Falha temporária. Tentando novamente. "+$_.Exception.Message}})
$extend.Add_Click({
    try{if($script:phase -eq 'waiting' -and (Confirm-Key)){Start-Rest}}
    catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message)}
})
$button.Add_Click({
    try{
        if($script:phase -in 'waiting','rest','relock'){Start-Focus;return}
        if($script:phase -eq 'study'){if((Confirm-Key) -and $script:phase -eq 'study'){Start-Rest};return}
        if(!($apps.CheckedItems.Count+$sites.CheckedItems.Count)){Show-Menu $false;[Windows.Forms.MessageBox]::Show('Marque um aplicativo ou site.');return}
        if([string]::IsNullOrWhiteSpace($key.Text) -or $key.Text -cne $repeat.Text){[void][Windows.Forms.MessageBox]::Show('Digite a mesma senha nos dois campos.');return}
        Save-List
        Start-Focus
        Set-Editing $false
        $timer.Start()
    }catch{[Windows.Forms.MessageBox]::Show($_.Exception.Message)}
})
$form.Add_FormClosing({
    param($sender,$eventArgs)
    try{
        if($script:phase -ne 'idle'){
            if(!(Confirm-Key)){$eventArgs.Cancel=$true;return}
            Set-Sites @()
        }
        Save-List
    }catch{$eventArgs.Cancel=$true;[Windows.Forms.MessageBox]::Show($_.Exception.Message)}
})
[void]$form.ShowDialog()
$mutex.ReleaseMutex()
$mutex.Dispose()
