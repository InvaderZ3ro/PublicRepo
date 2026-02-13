(Get-Date).Date
return "This is a test"

#to invoke the script
#  $scriptContent = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/InvaderZ3ro/PublicRepo/refs/heads/main/test.ps1" -UseBasicParsing
#  $scriptBlock = [Scriptblock]::Create($scriptContent.Content)
#  Invoke-Command -ScriptBlock $scriptBlock
