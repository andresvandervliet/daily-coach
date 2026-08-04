# therapy-reminder.ps1
# Stuurt een voorbereiding-email twee dagen voor de eerste therapiesessie (10-8-2026)

$gmailUser = "andresvandervliet@gmail.com"
$gmailPass = "ecwbreqgctvqeiau"

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
.ti{font-size:28px;font-weight:300;color:#F0EDE8;margin-bottom:6px}
.sub{font-size:14px;color:#7A7570;margin-bottom:32px}
hr{border:none;border-top:1px solid #1A1A1A;margin:28px 0}
.sl{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:#7A7570;margin-bottom:12px}
.tip{background:rgba(201,168,76,.07);border-left:2px solid #C9A84C;border-radius:0 8px 8px 0;padding:13px 16px;margin-bottom:10px;font-size:14px;line-height:1.65;color:#F0EDE8}
.tip strong{color:#E2C97E}
.ct{text-align:center;margin:36px 0 8px}
.cb{display:inline-block;background:#C9A84C;color:#0A0A0A;text-decoration:none;padding:15px 40px;border-radius:8px;font-size:12px;font-weight:700;letter-spacing:.1em;text-transform:uppercase}
.ma{text-align:center;font-size:14px;color:#7A7570;line-height:1.9;margin-top:32px;font-style:italic}
.fo{text-align:center;font-size:11px;color:#2A2A2A;margin-top:32px}
</style>
</head>
<body>
<div class='w'>
  <div class='ey'>Daily Coach &middot; Therapie Voorbereiding</div>
  <div class='ti'>Overmorgen is het zover.</div>
  <div class='sub'>Zondag 10 augustus &mdash; eerste sessie met je psycholoog.</div>
  <hr>
  <div class='sl'>Zo bereid je je voor</div>
  <div class='tip'><strong>Kies one thema.</strong> Niet drie. Eén ding dat nu het meeste weegt, concreet geformuleerd. Je psycholoog vraagt altijd: wat wil je vandaag bespreken?</div>
  <div class='tip'><strong>Formuleer als situatie, niet als analyse.</strong> Niet "ik heb moeite met grenzen" maar "deze week zei ik ja terwijl ik nee bedoelde, en ik wil begrijpen waarom."</div>
  <div class='tip'><strong>Zeg wat je wilt bereiken.</strong> Inzicht? Een oefening? Erkenning? Benoem het direct aan het begin van de sessie &mdash; dan werkt de tijd gerichter.</div>
  <div class='tip'><strong>Neem je journalnotities mee.</strong> De afgelopen dagen heb je dingen opgeschreven. Kijk terug. Wat valt op? Wat herhalt zich?</div>
  <div class='tip'><strong>Na de sessie (binnen 10 minuten).</strong> Open de Daily Coach app en schrijf op: wat was het belangrijkste inzicht? Wat wil je onthouden? Dit verankert het.</div>
  <div class='ct'><a href='COACH_APP_URL' class='cb'>Open Daily Coach</a></div>
  <div class='ma'>Jij bent niet kapot. Je leert jezelf opnieuw kennen.<br>Dat vraagt moed. Die heb je.</div>
  <div class='fo'>Daily Coach &middot; Therapie Voorbereiding 10 augustus 2026</div>
</div>
</body>
</html>
"@

$subject = "Therapie overmorgen - zo bereid je je voor"

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
