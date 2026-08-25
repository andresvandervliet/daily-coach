# sessie-reminder.ps1
# Stuur voorbereiding-email twee dagen voor een therapiesessie
# Gebruik: powershell -File sessie-reminder.ps1 -SessieDatum "2026-08-17" -SessieTijd "09:00" -SessieLocatie "Vaart Z.Z. 37, Assen"

param(
    [string]$SessieDatum    = "2026-08-10",
    [string]$SessieTijd     = "10:00",
    [string]$SessieLocatie  = "Assen"
)

$gmailUser = "andresvandervliet@gmail.com"
$gmailPass = $env:DAILY_COACH_GMAIL_APP_PASSWORD
if (-not $gmailPass) { Write-Error "Omgevingsvariabele DAILY_COACH_GMAIL_APP_PASSWORD is niet ingesteld."; exit 1 }

$sessieDate = [datetime]::Parse($SessieDatum)
$dagNaam = $sessieDate.ToString("dddd d MMMM", [System.Globalization.CultureInfo]::GetCultureInfo("nl-NL"))
$dagNaamCapitalized = $dagNaam.Substring(0,1).ToUpper() + $dagNaam.Substring(1)

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
  <div class="ey">Daily Coach &middot; Therapie Voorbereiding</div>
  <div class="ti">Overmorgen: sessie met je psycholoog.</div>
  <div class="meta">$dagNaamCapitalized &middot; $SessieTijd &middot; $SessieLocatie</div>
  <hr>
  <div class="sl">Zo bereid je je voor</div>
  <div class="tip"><strong>Kies een thema.</strong> Niet drie. Formuleer het als concrete situatie: "Deze week zei ik ja terwijl ik nee bedoelde" werkt beter dan "ik heb moeite met grenzen."</div>
  <div class="tip"><strong>Zeg wat je wilt bereiken.</strong> Inzicht, een concrete oefening, of gewoon erkenning? Benoem dit aan het begin van de sessie zodat de tijd goed gebruikt wordt.</div>
  <div class="tip"><strong>Kijk terug in je journal.</strong> De afgelopen dagen heb je dingen opgeschreven. Wat valt op? Wat herhaalt zich? Dat is je materiaal.</div>
  <div class="tip"><strong>Na de sessie, direct opschrijven.</strong> Open de Daily Coach app binnen 10 minuten na de sessie en noteer: het belangrijkste inzicht en wat je wilt vasthouden.</div>
  <div class="ct"><a href="https://merry-kelpie-eec436.netlify.app" class="cb">Open Daily Coach</a></div>
  <div class="ma">Jij bent niet kapot. Je leert jezelf opnieuw kennen.<br>Dat vraagt moed. Die heb je.</div>
  <div class="fo">Daily Coach &middot; Voorbereiding $dagNaamCapitalized</div>
</div>
</body>
</html>
"@

$subject = "Therapie overmorgen - $dagNaamCapitalized $SessieTijd"

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
