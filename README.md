# Supportworks Cookbook

Installs and configures Supportworks >= 8.1

## Requirements




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
    <td><tt>['Supportworks_82']['bacon']</tt></td>
    <td>Boolean</td>
    <td>whether to include bacon</td>
    <td><tt>true</tt></td>
  </tr>
</table>

## Usage

### Supportworks_82::default

TODO: Write usage instructions for each cookbook.


Just include `Supportworks_82` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[Supportworks_82]"
  ]
}
```

## Contributing

TODO: (optional) If this is a public cookbook, detail the process for contributing. If this is a private cookbook, remove this section.


1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

## License and Authors

Authors: Rich Gordon
License: MIT

