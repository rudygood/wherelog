$paramString = Read-Host -Prompt "Enter the commit text:"
git add -A
git status
Read-Host -Prompt "Press Enter to continue..."
git commit -m "$paramString"
Read-Host -Prompt "Press Enter to continue..."
git push