flutter pub get
if (!(dart format --set-exit-if-changed .)) {
    Write-Host "::warning title=Formatting::代码未通过 dart format；请运行 dart format ."
}
else {
    Write-Host "::notice title=Formatting::代码已通过 dart format。"
}

if (!(flutter analyze)) {
    Write-Host "::warning title=Static analysis::flutter analyze 发现异常，请查看日志。"
}
else {
    Write-Host "::notice title=Static analysis::flutter analyze 未发现异常。"
}

if (Test-Path -Path "test/**/*.dart" -PathType Leaf) {
    flutter test
}
python3 -m unittest discover -s pybuilds/tests -v
Pause