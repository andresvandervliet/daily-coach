# mbct-reminder.ps1
# Draait dagelijks (18:00); stuurt een herinnering de avond voor elke
# MBCT-bijeenkomst (mindfulness, De Vaart Leefstijl), plus een aparte
# herinnering een week voor de start om het oefenboek te kopen.
# Dezelfde datums staan in index.html (MBCT_SESSIONS).
#
# Testen zonder te wachten:  powershell -File mbct-reminder.ps1 -Vandaag 2027-01-10
# Alleen kijken, niet versturen: voeg -DryRun toe.
#
# Let op: de mailtekst bevat bewust NIET de woorden "Daily Coach",
# zodat het Gmail-filter voor Daily Coach-mails deze herinnering niet
# uit de inbox haalt.

param(
  [string]$Vandaag = (Get-Date).ToString("yyyy-MM-dd"),
  [switch]$DryRun
)

$gmailUser = "andresvandervliet@gmail.com"

$bijeenkomsten = @(
  @{ Datum = "2027-01-11"; Nr = 1; Noot = "" },
  @{ Datum = "2027-01-25"; Nr = 2; Noot = "" },
  @{ Datum = "2027-02-08"; Nr = 3; Noot = "" },
  @{ Datum = "2027-02-22"; Nr = 4; Noot = "" },
  @{ Datum = "2027-03-08"; Nr = 5; Noot = "" },
  @{ Datum = "2027-03-22"; Nr = 6; Noot = "" },
  @{ Datum = "2027-04-12"; Nr = 7; Noot = "" },
  @{ Datum = "2027-05-10"; Nr = 8; Noot = "" },
  @{ Datum = "2027-05-24"; Nr = 9; Noot = "eventuele uitloop / inhalen" }
)
$boekHerinnering = "2027-01-04"   # een week voor de eerste bijeenkomst

$nl = [System.Globalization.CultureInfo]::GetCultureInfo("nl-NL")
$vandaagDt = [datetime]::ParseExact($Vandaag, "yyyy-MM-dd", $null)
$morgen = $vandaagDt.AddDays(1).ToString("yyyy-MM-dd")
$sessie = $bijeenkomsten | Where-Object { $_.Datum -eq $morgen }
$isBoekDag = ($Vandaag -eq $boekHerinnering)

if (-not $sessie -and -not $isBoekDag) { exit 0 }

$style = @"
body{margin:0;padding:0;background:#0A0A0A;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#F0EDE8}
.w{max-width:560px;margin:0 auto;padding:40px 24px 60px}
.ey{font-size:11px;letter-spacing:.12em;text-transform:uppercase;color:#C9A84C;margin-bottom:8px}
.ti{font-size:28px;font-weight:300;color:#F0EDE8;margin-bottom:6px}
.meta{font-size:14px;color:#7A7570;margin-bottom:32px}
hr{border:none;border-top:1px solid #1A1A1A;margin:28px 0}
.step{background:rgba(201,168,76,.08);border-radius:8px;padding:16px 18px;margin-bottom:10px;font-size:14px;line-height:1.65;color:#F0EDE8}
.step strong{color:#E2C97E}
.ct{text-align:center;margin:36px 0 8px}
.cb{display:inline-block;background:#C9A84C;color:#0A0A0A;text-decoration:none;padding:15px 40px;border-radius:8px;font-size:12px;font-weight:700;letter-spacing:.1em;text-transform:uppercase}
.fo{text-align:center;font-size:11px;color:#2A2A2A;margin-top:32px}
"@

if ($sessie) {
  $dagTxt = [datetime]::ParseExact($sessie.Datum, "yyyy-MM-dd", $null).ToString("dddd d MMMM", $nl)
  $noot = if ($sessie.Noot) { " ($($sessie.Noot))" } else { "" }
  $extra = if ($sessie.Nr -eq 1) { "<div class='step'><strong>Eerste keer.</strong> Je hoeft nog niets gelezen te hebben. Kom op tijd, zodat je rustig kunt beginnen.</div>" } else { "" }
  $subject = "Morgen mindfulness-training - bijeenkomst $($sessie.Nr), 9:00"
  $body = @"
<!DOCTYPE html><html lang="nl"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>$style</style></head>
<body><div class="w">
  <div class="ey">Herinnering &middot; Mindfulness-training (MBCT)</div>
  <div class="ti">Morgen: bijeenkomst $($sessie.Nr)$noot</div>
  <div class="meta">$dagTxt &middot; 09:00 &ndash; 11:00</div>
  <hr>
  <div class="step"><strong>Waar:</strong> De Vaart Leefstijl, Oosterhoutstraat 9a, 9401 NA Assen. Groepsruimte op de bovenste etage, er is een lift. Parkeren kan bij het pand.</div>
  <div class="step"><strong>Neem mee:</strong> het Mindfulness Oefenboek (Teasdale, Williams &amp; Segal).</div>
  $extra
  <div class="ct"><a href="https://merry-kelpie-eec436.netlify.app" class="cb">Open de coach-app</a></div>
  <div class="fo">Herinnering mindfulness-training &middot; De Vaart Leefstijl</div>
</div></body></html>
"@
} else {
  $subject = "Over een week start de mindfulness-training - koop het oefenboek"
  $body = @"
<!DOCTYPE html><html lang="nl"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>$style</style></head>
<body><div class="w">
  <div class="ey">Herinnering &middot; Mindfulness-training (MBCT)</div>
  <div class="ti">Over een week begint de training</div>
  <div class="meta">Eerste bijeenkomst: maandag 11 januari 2027 &middot; 09:00 &ndash; 11:00</div>
  <hr>
  <div class="step"><strong>Koop het boek:</strong> Mindfulness Oefenboek van John Teasdale, Mark Williams en Zindel Segal. Je hoeft er voor de eerste bijeenkomst nog niets in gelezen te hebben.</div>
  <div class="step"><strong>Waar:</strong> De Vaart Leefstijl, Oosterhoutstraat 9a, 9401 NA Assen (bovenste etage, lift aanwezig).</div>
  <div class="step"><strong>Alle data:</strong> 11 en 25 jan, 8 en 22 feb, 8 en 22 mrt, 12 apr, 10 mei, en 24 mei (reserve). Steeds maandag 09:00 &ndash; 11:00.</div>
  <div class="fo">Herinnering mindfulness-training &middot; De Vaart Leefstijl</div>
</div></body></html>
"@
}

if ($DryRun) {
  Write-Output "DRYRUN vandaag=$Vandaag -> onderwerp: $subject"
  exit 0
}

$gmailPass = [System.Environment]::GetEnvironmentVariable("DAILY_COACH_GMAIL_APP_PASSWORD","User")
if (-not $gmailPass) { Write-Error "Omgevingsvariabele DAILY_COACH_GMAIL_APP_PASSWORD is niet ingesteld."; exit 1 }

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
Write-Output "Verstuurd: $subject"
