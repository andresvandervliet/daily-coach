# week-reminder.ps1
# Stuurt elke zondag 20:00 een email om de weekreflectie in te vullen

$gmailUser = "andresvandervliet@gmail.com"
$gmailPass = $env:DAILY_COACH_GMAIL_APP_PASSWORD
if (-not $gmailPass) { Write-Error "Omgevingsvariabele DAILY_COACH_GMAIL_APP_PASSWORD is niet ingesteld."; exit 1 }

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
.sl{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:#7A7570;margin-bottom:12px}
.tip{background:rgba(201,168,76,.08);border-radius:8px;padding:13px 16px;margin-bottom:8px;font-size:14px;line-height:1.65;color:#F0EDE8}
.tip strong{color:#E2C97E}
.ct{text-align:center;margin:36px 0 8px}
.cb{display:inline-block;background:#C9A84C;color:#0A0A0A;text-decoration:none;padding:15px 40px;border-radius:8px;font-size:12px;font-weight:700;letter-spacing:.1em;text-transform:uppercase}
.ma{text-align:center;font-size:14px;color:#7A7570;line-height:1.9;margin-top:32px;font-style:italic}
.fo{text-align:center;font-size:11px;color:#2A2A2A;margin-top:32px}
</style>
</head>
<body>
<div class="w">
  <div class="ey">Daily Coach &middot; Weekreflectie</div>
  <div class="ti">De week zit erop.</div>
  <div class="meta">Neem 5 minuten voor jezelf.</div>
  <hr>
  <div class="sl">Wat de weekreflectie doet</div>
  <div class="tip"><strong>Patronen zichtbaar maken.</strong> Eén dag zegt weinig. Een week zegt alles. Wat herhaalde zich deze week?</div>
  <div class="tip"><strong>Groei erkennen.</strong> Niet alleen wat er mis ging. Ook wat je beter deed dan de week ervoor.</div>
  <div class="tip"><strong>Volgende week scherper starten.</strong> Wie of wat vroeg het meeste van je? Wat wil je anders?</div>
  <hr>
  <div class="sl">Financieel</div>
  <div class="tip"><strong>Check je Knab saldo's.</strong> Open je Knab app, lees het saldo van elke pas, en vul het in bij Financien. Kost 30 seconden, geeft je compleet overzicht.</div>
  <div class="ct"><a href="https://merry-kelpie-eec436.netlify.app" class="cb">Open Daily Coach &rarr; Week</a></div>
  <div class="ma">Een week bewust leven is meer dan zeven dagen overleven.</div>
  <div class="fo">Daily Coach &middot; Weekreflectie &middot; Elke zondag</div>
</div>
</body>
</html>
"@

$subject = "Weekreflectie invullen - hoe was jouw week?"

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
