# Supportworks Cookbook

Installs and configures Supportworks >= 8.1

## Requirements

- Create a mysql user on your current production server to use as the migration account
   - ```GRANT select on *.* to 'migrate'@'<new server ip> identified by 'password'```
- Download the required installation media and save it to D:\swmedia
  - CsSetup.msi: https://files.hornbill.com/coreservices/R_CS_6_0_0/CsSetup.msi
  - SwSetup.exe: https://files.hornbill.com/supportworks/R_SW_8_2_0/SwSetup.exe
  - ITSM_DEFAULT_420: https://github.com/richbai90/BTI_Zapps/blob/master/ITSM_Default_421.zapp
### Platforms

- Microsoft Windows Server >= 2012

### Chef

- Tested on chef 12.18.31


## Attributes

TODO: List your cookbook attributes here.


### Supportworks_82::default

<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt></tt></td>
    <td></td>
    <td></td>
    <td><tt></tt></td>
  </tr>
</table>

## Usage

### Supportworks_82::default


- Download Chef DK
- Create a folder called D:\cookbooks
- Clone this repo into that folder and rename it to supportworks
- In a new powershell window (not chef-dk) cd to D:\ and run `chef-client -A -z -o supportworks`

## License and Authors

Authors: Rich Gordon
License: MIT

