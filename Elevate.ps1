
function global:Test-IsAdmin
{
    $wi = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = new-object 'System.Security.Principal.WindowsPrincipal' $wi
    $wp.IsInRole("Administrators") -eq 1
}

function global:Open-Elevated
{
  param([switch]$wait)
  $file, [string]$arguments = $args;

  if (!(Test-IsAdmin))
  {
    $psi = new-object System.Diagnostics.ProcessStartInfo $file;
    $psi.Arguments = $arguments;
    $psi.Verb = "runas";
    $p = [System.Diagnostics.Process]::Start($psi);
    if ($wait.IsPresent)
    {
        $p.WaitForExit()
    }
  }
  else
  {
    & $file $args
  }
}
set-alias elevate Open-Elevated -scope global

