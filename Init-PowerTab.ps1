################ Start of PowerTab Initialization Code ########################
#
#

function __init-powertab
{
  $configurationLocation = $myhome+'\WindowsPowerShell'
  $configFile = $configurationLocation+'\PowerTabConfig.xml'
  Import-Module "PowerTab" -ArgumentList $configFile
}

#__init-powertab


################ End of PowerTab Initialization Code ##########################

