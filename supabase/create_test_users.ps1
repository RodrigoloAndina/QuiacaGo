param(
  [switch]$Create,
  [string]$ServiceRoleKey
)

$ErrorActionPreference = 'Stop'

if (-not $Create) {
  Write-Host 'Modo seguro: no crea cuentas.'
  Write-Host 'Uso: .\supabase\create_test_users.ps1 -Create'
  exit 0
}

$source = Get-Content (Join-Path $PSScriptRoot '..\lib\services\supabase_service.dart') -Raw
$url = [regex]::Match($source, "defaultValue: '([^']+supabase\.co)'").Groups[1].Value

if ([string]::IsNullOrWhiteSpace($url)) {
  throw 'No se pudo leer la URL de Supabase desde lib/services/supabase_service.dart.'
}

if ([string]::IsNullOrWhiteSpace($ServiceRoleKey)) {
  $secureKey = Read-Host 'Pegá la service_role key de Supabase (se ocultará)' -AsSecureString
  $ServiceRoleKey = [System.Net.NetworkCredential]::new('', $secureKey).Password
}

if ([string]::IsNullOrWhiteSpace($ServiceRoleKey)) {
  throw 'La service_role key es obligatoria para crear usuarios confirmados sin enviar correos.'
}

$password = 'QuiacaTest1!'
$users = @()
1..5 | ForEach-Object {
  $users += [pscustomobject]@{
    role = 'passenger'
    email = "pasajero$($_)@pruebas.quiacago.com.ar"
    name = "Pasajero Prueba $_"
    phone = "+54388500000$_"
  }
}
1..5 | ForEach-Object {
  $users += [pscustomobject]@{
    role = 'driver'
    email = "chofer$($_)@pruebas.quiacago.com.ar"
    name = "Chofer Prueba $_"
    phone = "+54388510000$_"
  }
}

$headers = @{
  apikey = $ServiceRoleKey
  Authorization = "Bearer $ServiceRoleKey"
}
$provisionerUserAgent = 'QuiacaGo-Test-User-Provisioner/1.0'

Write-Host "Creando $($users.Count) cuentas confirmadas con contraseña común: $password"
foreach ($user in $users) {
  $body = @{
    email = $user.email
    password = $password
    email_confirm = $true
    user_metadata = @{
      full_name = $user.name
      phone = $user.phone
      role = $user.role
    }
    app_metadata = @{
      role = $user.role
    }
  } | ConvertTo-Json -Depth 5

  try {
    $response = Invoke-RestMethod "$url/auth/v1/admin/users" -Method Post -Headers $headers -UserAgent $provisionerUserAgent -ContentType 'application/json' -Body $body
    [pscustomobject]@{
      Tipo = $user.role
      Usuario = $user.email
      Password = $password
      UserId = $response.id
      Confirmado = ($response.email_confirmed_at -ne $null)
    }
  } catch {
    $details = $_.ErrorDetails.Message
    if ($details -match 'already.*registered|already.*exists|email_exists') {
      Write-Warning "$($user.email): ya existe; no se modificó."
    } else {
      Write-Warning "$($user.email): $details"
    }
  }
}

Write-Host ''
Write-Host 'Importante: aprobá los documentos de los choferes desde el panel antes de probar viajes.'
