@echo off
Write-Host ""
Write-Host ""
Write-Host "----running wherelog flutter clean----" -BackgroundColor Cyan -ForegoundColor Black
Write-Host "flutter clean" -BackgroundColor Cyan -ForegoundColor Black
call flutter clean
Write-Host ""
Write-Host ""
Write-Host "----running wherelog puB get----" -BackgroundColor Cyan -ForegoundColor Black
Write-Host "flutter pub get" -BackgroundColor Cyan -ForegoundColor Black
call flutter pub get
Write-Host ""
Write-Host ""
Write-Host "----running wherelog flutter compile----" -BackgroundColor Cyan -ForegoundColor Black
Write-Host "flutter run -d 9878005C7462164" -BackgroundColor Cyan -ForegoundColor Black
call flutter run -d 9878005C7462164
Write-Host "----END of wherelog flutter compile----" -BackgroundColor White -ForegoundColor Black

