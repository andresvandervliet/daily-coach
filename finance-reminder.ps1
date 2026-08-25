# finance-reminder.ps1
# Stuurt op de 22e van elke maand een financiele herinnering

$gmailUser = "andresvandervliet@gmail.com"
$gmailPass = $env:DAILY_COACH_GMAIL_APP_PASSWORD
if (-not $gmailPass) { Write-Error "Omgevingsvariabele DAILY_COACH_GMAIL_APP_PASSWORD is niet ingesteld."; exit 1 }

$maand = (Get-Date).ToString("MMMM yyyy", [System.Globalization.CultureInfo]::GetCultureInfo("nl-NL"))
$maandCap = $maand.Substring(0,1).ToUpper() + $maand.Substring(1)

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
.step{background:rgba(201,168,76,.08);border-radius:8px;padding:16px 18px;margin-bottom:10px;font-size:14px;line-height:1.65;color:#F0EDE8}
.step strong{color:#E2C97E}
.num{display:inline-block;background:#C9A84C;color:#0A0A0A;width:22px;height:22px;border-radius:50%;text-align:center;line-height:22px;font-size:11px;font-weight:700;margin-right:10px}
.ct{text-align:center;margin:36px 0 8px}
.cb{display:inline-block;background:#C9A84C;color:#0A0A0A;text-decoration:none;padding:15px 40px;border-radius:8px;font-size:12px;font-weight:700;letter-spacing:.1em;text-transform:uppercase}
.tip{background:#111;border:1px solid #1E1E1E;border-radius:10px;padding:20px 22px;margin-top:24px}
.tip-t{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:#C9A84C;margin-bottom:10px}
.tip-b{font-size:13px;line-height:1.7;color:#D0CEC9}
.ma{text-align:center;font-size:14px;color:#7A7570;line-height:1.9;margin-top:32px;font-style:italic}
.fo{text-align:center;font-size:11px;color:#2A2A2A;margin-top:32px}
</style>
</head>
<body>
<div class="w">
  <div class="ey">Daily Coach &middot; Financieel Overzicht</div>
  <div class="ti">Salarisdag, Andres.</div>
  <div class="meta">$maandCap &middot; tijd om je financien bij te werken.</div>
  <hr>
  <div class="sl">3 stappen, 2 minuten</div>
  <div class="step"><span class="num">1</span><strong>Salaris ontvangen?</strong><br>Open de Financien tab en klik op "Ontvangen". Vul het werkelijke bedrag in als het afwijkt.</div>
  <div class="step"><span class="num">2</span><strong>Knab saldo's checken.</strong><br>Open je Knab app, lees het saldo van elke pas, en tik het in. De app berekent automatisch wat je hebt uitgegeven en bespaard.</div>
  <div class="step"><span class="num">3</span><strong>Vaste lasten afvinken.</strong><br>Scroll door je vaste lasten en markeer alles wat al van je rekening is gegaan.</div>
  <div class="ct"><a href="https://merry-kelpie-eec436.netlify.app" class="cb">Open Financien</a></div>
  <div class="tip">
    <div class="tip-t">Bespaartip</div>
    <div class="tip-b">Kijk naar het verschil tussen "Nu vrij te besteden" en "Echt restant". Dat tussenliggende bedrag gaat de komende weken nog van je rekening. Houd daar rekening mee voordat je iets groots koopt.</div>
  </div>
  <div class="ma">Financiele rust begint met weten waar je staat.<br>En dat weet je nu.</div>
  <div class="fo">Daily Coach &middot; $maandCap</div>
</div>
</body>
</html>
"@

$subject = "Salarisdag - financien bijwerken ($maandCap)"

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
