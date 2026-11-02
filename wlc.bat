echo ""
echo "----running wherelog flutter clean----"
echo "flutter clean"
call flutter clean
echo "----running wherelog puB get----"
echo "flutter pub get"
call flutter pub get
echo "----running wherelog flutter compile----"
echo "flutter run -d 9878005C7462164"
call flutter run -d 9878005C7462164
echo "----END of wherelog flutter compile----"
