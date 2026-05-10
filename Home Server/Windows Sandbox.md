# Windows Sandbox | Powershell
Windows Sandbox is a secure, isolated environment (VM) on Windows Pro and Enterprise. It creates a temporary, disposable instance of Windows, ensuring any changes made do not effect to the Host machine.
- Microsoft introduced a Windows Sandbox CLI for scripting and automation, alongside community tools like CustomSandbox for advanced configuration.
- Automating Windows Sandbox can greatly streamline testing, development, and secure execution of applications.

(michaelsendpoint)[michaelsendpoint.com]

 
## Using Windows Sandbox CLI

1. Start a Sandbox
```
wsb start
```
To start with custom settings:
```
wsb start --config "<Configuration><Networking>Disabled</Networking></Configuration>"
```
2. List Running Sandboxes
```
wsb list
```
3. Execute Commands Inside Sandbox
```
wsb exec --id <sandbox-id> -c "app.exe" -r System
```
4. Share Folders
```
wsb share --id <sandbox-id> -f C:\host\folder -s C:\sandbox\folder --allow-write
```
5. Stop a Sandbox
```
wsb stop --id <sandbox-id>
```


# CustomSandbox
(Github)[https://github.com/oOblik/CustomSandbox]

## GitHub - oOblik/CustomSandbox
- CustomSandbox is a PowerShell utility to facilitate quick automatic configuration of Windows Sandbox. Write custom tasks to install software or configure Windows in the sandbox immediately after launch.
- Do you frequently use Windows Sandbox but are tired of having to install common utilities on every launch? Then This is the Tool You wants.

## Features
- Configure the following Windows Sandbox features before launch:
    - Protected Mode
    - Networking


## Download & Extract

- Invoke-WebRequest ` 'https://github.com/oOblik/CustomSandbox/releases/latest/download/CustomSandbox.zip' -OutFile .\CustomSandbox.zip `
- Expand-Archive ` .\CustomSandbox.zip .\ `
- ` cd CustomSandbox `
- Run the Script ` \CustomSandbox.ps1 `
- Verification: After automation setup, run `wsb` list to confirm sandbox sessions and configurations.




