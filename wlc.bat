echo "----running wherelog flutter clean----"
call flutter clean
echo "----running wherelog pug get----"
call flutter pub get
echo "----running wherelog flutter compile----"
call flutter run -d 9878005C7462164
echo "----END of wherelog flutter compile----"
pause
