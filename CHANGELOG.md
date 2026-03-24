# CHANGELOG

This file contains all the latest changes and updates to this application.

## [1.4.0](https://github.com/krystal/xero_exporter/compare/v1.3.0...v1.4.0) (2026-03-24)


### Features

* add support for custom invoice numbers & tracking categories ([98ef9d2](https://github.com/krystal/xero_exporter/commit/98ef9d2bff4fa2d995499d217d5d9b054c311540))
* separate fees from payments ([2588a46](https://github.com/krystal/xero_exporter/commit/2588a46ad0283ef1ca5bfd8fd3f0b58316752122))
* support for custom loggers for API & execution ([2d9f770](https://github.com/krystal/xero_exporter/commit/2d9f7709dbc288823839e4f00ebdc689d8a8a781))
* support for named account codes and reverse charge ([dd731a5](https://github.com/krystal/xero_exporter/commit/dd731a5aa0a62834a2d801fef598958724979482))
* support optional country and custom tax rate names on invoices ([eb15001](https://github.com/krystal/xero_exporter/commit/eb15001ee588ccf0c67976ad58a32a44ff1afa3b))


### Bug Fixes

* add rubocop-rspec to fix CI lint failures ([5c7e4a3](https://github.com/krystal/xero_exporter/commit/5c7e4a3fb0a53bed0ed109bb52a8c4e170902f4a))
* don't use [@current](https://github.com/current)_state unless it exists ([71f6380](https://github.com/krystal/xero_exporter/commit/71f6380f78ca9ebeea75a636d84c29f1e616894f))
* lookup tax rates including the country name and code ([87fb161](https://github.com/krystal/xero_exporter/commit/87fb16168eb4212db916b6c14d4255b370d35b7b))
* run release please on changes to main rather than master ([eda2493](https://github.com/krystal/xero_exporter/commit/eda249368217f4960f329b01339d06aec52dc026))
* support for country names in moss accounts ([ce62d29](https://github.com/krystal/xero_exporter/commit/ce62d2908a4ebb56ceca2801d5c3b78ede62eff7))

## 1.3.0

### Features

- separate fees from payments ([2588a4](https://github.com/krystal/xero_exporter/commit/2588a46ad0283ef1ca5bfd8fd3f0b58316752122))

## 1.2.1

### Bug Fixes

- lookup tax rates including the country name and code ([87fb16](https://github.com/krystal/xero_exporter/commit/87fb16168eb4212db916b6c14d4255b370d35b7b))
- support for country names in moss accounts ([ce62d2](https://github.com/krystal/xero_exporter/commit/ce62d2908a4ebb56ceca2801d5c3b78ede62eff7))

## 1.2.0

### Features

- add support for custom invoice numbers & tracking categories ([98ef9d](https://github.com/krystal/xero_exporter/commit/98ef9d2bff4fa2d995499d217d5d9b054c311540))

### Bug Fixes

- don't use @current_state unless it exists ([71f638](https://github.com/krystal/xero_exporter/commit/71f6380f78ca9ebeea75a636d84c29f1e616894f))

## 1.1.0

### Features

- support for custom loggers for API & execution ([2d9f77](https://github.com/krystal/xero_exporter/commit/2d9f7709dbc288823839e4f00ebdc689d8a8a781))

## 1.0.0

### Features

- support for named account codes and reverse charge ([dd731a](https://github.com/krystal/xero_exporter/commit/dd731a5aa0a62834a2d801fef598958724979482))

## 1.0.0-alpha.1
