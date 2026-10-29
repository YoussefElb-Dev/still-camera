$ErrorActionPreference='Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCommand) { $flutterPath = $flutterCommand.Source }
elseif (Test-Path -LiteralPath 'C:\Users\youss\.cache\still-camera-flutter\bin\flutter.bat') { $flutterPath = 'C:\Users\youss\.cache\still-camera-flutter\bin\flutter.bat' }
elseif (Test-Path -LiteralPath '.tooling\flutter\bin\flutter.bat') { $flutterPath = Join-Path $projectRoot '.tooling\flutter\bin\flutter.bat' }
else { throw 'Install the Flutter SDK and add flutter to PATH.' }
& $flutterPath pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency setup failed.' }
& $flutterPath analyze --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
& $flutterPath test --no-pub
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
& $flutterPath build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
New-Item -ItemType Directory -Path artifacts -Force | Out-Null
Copy-Item -LiteralPath 'build\app\outputs\flutter-apk\app-release.apk' -Destination 'artifacts\Still-Camera.apk'
Write-Output 'Built artifacts\Still-Camera.apk'
