FIXME
-----

* Apple Watch app:
  - the Monitor countdown doesn't update on rescan
  - readings aren't received in background but Bluetooth connections aren't closed until shutdown, even when the app is removed from the Dock
* Bubble: the Apple Watch app doesn't connect to it
* when the sensor is not detected the last reading time is updated anyway
* the log ScrollView doesn't remember the position when switching tabs, nor allows scrolling to the top when reversed

TODO
----

* clean the code base by restarting from a fresh Xcode 12 project template and make use of await/async, Combine and the new Widgets, @Scene/AppStorage, ScrollViewReaders, lazy grids...
* selection of glucose units
* manage Nightscout JavaScript alerts synchronously
* Apple Watch app: calibration, snapshots, workout and extended runtime background sessions, complications
* log: limit to a number of readings, prepend time, add a search field, Share menu, record to a file
* more modern Swift idioms: property wrappers, @dynamicCallable/MemberLookup, ViewModifiers/Builders


PLANS / WISHES
---------------

* a predictive meal log using Machine Learning (see [WoofWoof](https://github.com/gshaviv/ninety-two))
* LoopKit integrations
