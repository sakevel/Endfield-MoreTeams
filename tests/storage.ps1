$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('zml-moreteams-storage-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $root | Out-Null
try {
  $file=Join-Path $root 'teams-test.txt';$temp=$file+'.tmp';$backup=$file+'.bak';$utf8=[Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllText($temp,"初始编队",$utf8);[IO.File]::Move($temp,$file)
  [IO.File]::WriteAllText($temp,"已更新编队",$utf8);[IO.File]::Replace($temp,$file,$backup)
  if([IO.File]::ReadAllText($file) -ne "已更新编队" -or [IO.File]::ReadAllText($backup) -ne "初始编队"){throw 'Atomic replace/backup failed'}
  [IO.File]::WriteAllText($temp,"第二次更新",$utf8);[IO.File]::Replace($temp,$file,$backup)
  if([IO.File]::ReadAllText($backup) -ne "已更新编队"){throw 'Backup did not update'}
  $bytes=[IO.File]::ReadAllBytes($file);if($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191){throw 'Unexpected BOM'}
  $bad=Join-Path $root 'directory';New-Item -ItemType Directory $bad|Out-Null
  $failed=$false;try{[IO.File]::WriteAllText($bad,'failure',$utf8)}catch{$failed=$true}
  if(-not $failed -or [IO.File]::ReadAllText($file) -ne "第二次更新"){throw 'Failed write mutated healthy snapshot'}
  Copy-Item -LiteralPath $backup -Destination $temp;[IO.File]::Replace($temp,$file,$file+'.before-rollback')
  if([IO.File]::ReadAllText($file) -ne "已更新编队"){throw 'Rollback failed'}
  Write-Output 'PASS real .NET UTF8 atomic replace, successive backup, failed-write preservation and rollback in disposable copy'
} finally {
  $resolved=(Resolve-Path -LiteralPath $root).Path
  $base=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
  if(-not $resolved.StartsWith($base,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'zml-moreteams-storage-*'){throw 'Cleanup scope rejected'}
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
