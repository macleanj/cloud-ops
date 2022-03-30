# Overview
Overview of setting up the local PowerShell environment on MAC.

# Setup
- [Base setup](https://yellowdesert.consulting/2020/03/05/powershell-on-apple-mac-os-x/)
- [PROFILE setup](https://microsoft.github.io/AzureTipsAndTricks/blog/tip274.html)

## PROFILE setup
In the VS Code PowerShell window get the PowerShell profile file:
```
$PROFILE

# Response
/Users/jerome/.config/powershell/Microsoft.VSCode_profile.ps1
```
Edit the PowerShell profile file:
```
code $PROFILE
```

## Functions added
| function | description | sources |
|----------|-------------|---------|
| interactive_azcontext | Sets tenant and subscription interactively (reference only) | [source](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-powershell) |
|          |             |         |
