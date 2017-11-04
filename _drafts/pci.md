# PCI BDF and IDs of PCI devices
From OS's perspective, we have bus:device.function (BDF in short) for each PCI 
device. And, from a device vender's perspective, we have device\_id:class\_id for each 
device. BDF is dynamic allocated and depends on the slot that a PCI device plugins
in. However, PCI device's deivce\_id should be applied from PCI-intrested Group. 
And PCI device's class\_id depends on vender's emotion. See 
[this website](http://pci-ids.ucw.cz/) to find a PCI device's id infomation.

