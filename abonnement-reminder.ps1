# abonnement-reminder.ps1
# Draait dagelijks; stuurt een mail precies 7 dagen voordat een variabele-lasten
# abonnement afloopt (zie ook VARIABELE_LASTEN in index.html -zelfde bron).

$gmailUser = "andresvandervliet@gmail.com"
$gmailPass = [System.Environment]::GetEnvironmentVariable("DAILY_COACH_GMAIL_APP_PASSWORD","User")
if (-not $gmailPass) { Write-Error "Omgevingsvariabele DAILY_COACH_GMAIL_APP_PASSWORD is niet ingesteld."; exit 1 }

$abonnementen = @(
  @{ Naam = "IPTV";    GeldigTot = "2026-10-27" },
  @{ Naam = "NordVPN"; GeldigTot = "2028-05-03" }
)

$vandaag = Get-Date
$aflopend = $abonnementen | Where-Object {
  $geldigTot = [datetime]::ParseExact($_.GeldigTot, "yyyy-MM-dd", $null)
  ($geldigTot - $vandaag).Days -eq 7
}
if (-not $aflopend) { exit 0 }

$datumTxt = $vandaag.ToString("d MMMM yyyy", [System.Globalization.CultureInfo]::GetCultureInfo("nl-NL"))

$items = ($aflopend | ForEach-Object {
  $geldigTotTxt = ([datetime]::ParseExact($_.GeldigTot, "yyyy-MM-dd", $null)).ToString("d MMMM yyyy", [System.Globalization.CultureInfo]::GetCultureInfo("nl-NL"))
  "<div class=`"step`"><strong>$($_.Naam) loopt af op $geldigTotTxt.</strong><br>Nog 7 dagen -zeg op of verleng het, anders loopt het stil door.</div>"
}) -join "`n"

$namen = ($aflopend | ForEach-Object { $_.Naam }) -join ", "

$body = @"
<!DOCTYPE html>
<html lang="nl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body{margin:0;padding:0;background:#0A0A0A;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#F0EDE8}
.w{max-width:560px;margin:0 auto;padding:40px 24px 60px}
.ey{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:#C9A84C;margin-bottom:8px}
.ti{font-size:28px;font-weight:300;color:#F0EDE8;margin-bottom:6px;letter-spacing:-.01em}
.meta{font-size:13px;color:#7A7570;margin-bottom:32px}
hr{border:none;border-top:1px solid #1A1A1A;margin:28px 0}
.step{background:rgba(201,168,76,.08);border-radius:8px;padding:16px 18px;margin-bottom:10px;font-size:14px;line-height:1.65;color:#F0EDE8}
.step strong{color:#E2C97E}
.ct{text-align:center;margin:36px 0 8px}
.cb{display:inline-block;background:#C9A84C;color:#0A0A0A;text-decoration:none;padding:15px 40px;border-radius:8px;font-size:12px;font-weight:700;letter-spacing:.1em;text-transform:uppercase}
.ma{text-align:center;font-size:14px;color:#7A7570;line-height:1.9;margin-top:32px;font-style:italic}
.fo{text-align:center;font-size:11px;color:#2A2A2A;margin-top:32px}
</style>
</head>
<body>
<div class="w">
  <div class="ey">Daily Coach &middot; Variabele lasten</div>
  <div class="ti">Loopt over 7 dagen af.</div>
  <div class="meta">$datumTxt</div>
  <hr>
  $items
  <div class="ct"><a href="https://merry-kelpie-eec436.netlify.app" class="cb">Open Financien</a></div>
  <div class="ma">Op tijd opzeggen voorkomt een verlenging die je niet wilde.</div>
  <div class="fo">Daily Coach &middot; Abonnement herinnering</div>
</div>
</body>
</html>
"@

$subject = "Loopt over 7 dagen af: $namen"

$msg = New-Object Net.Mail.MailMessage
$msg.From = $gmailUser
$msg.To.Add($gmailUser)
$msg.Subject = $subject
$msg.Body = $body
$msg.IsBodyHtml = $true

$smtp = New-Object Net.Mail.SmtpClient("smtp.gmail.com", 587)
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object Net.NetworkCredential($gmailUser, $gmailPass)
$smtp.Send($msg)
$msg.Dispose()
