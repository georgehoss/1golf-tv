# one_golf_android_tv

1Golf Android TV App

## Development

Listado de dipositivos

`flutter devices`

Run app

`flutter run -d device-name`

## Release

## Android

`flutter build appbundle`

## IOs

`flutter build ios`

## Connection to Android TV

`adb connect ANDROID_TV_IP`

## Connection to tizen

`sdb connect 192.168.31.217`

`sdb connect 192.168.31.217:26101`

`sdb devices`

`flutter-tizen run`

`flutter-tizen build tpk`

`flutter-tizen install --release`
