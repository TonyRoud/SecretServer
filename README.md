# Secret Server PowerShell Module

This is a wrapper module for managing secret server with PowerShell. The module contains a set of functions which interface with the SecretServer PowerShell module from RamblingCookieMonster https://github.com/RamblingCookieMonster/SecretServer

After installing the SecretServer Module, you need to perform a one-time configuration to interface with SecretServer

## Instructions

```PowerShell
#One time setup:
    #Download the SecretServer repository https://github.com/RamblingCookieMonster/SecretServer
    #Unblock the zip file
    #Extract SecretServer folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

#Optional one time step: Set default Uri, create default proxy
    Set-SecretServerConfig -Uri https://FQDN.TO.SECRETSERVER/winauthwebservices/sswinauthwebservice.asmx
    New-SSConnection #Uses Uri we just set by default

#Each PowerShell session
    Import-Module SecretServer  #Alternatively, Import-Module "\\Path\To\SecretServer"

#List commands in the module
    Get-Command -Module SecretServer
```