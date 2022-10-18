# alpine-linux-zram
Create custom Alpine Linux live images with the root file system mounted on ZRAM and with a custom start-up script.

#1 setup an abuild user and clone the aports repository, just like it is described in the wiki

#2 copy the files inside the aports/scripts dir to your newly cloned aports/scripts dir

#3 go to aports/scripts dir and run ./custom-mkimage.sh --profile=someProfile --dir=someDirYouWantCopiedOnTheLiveImage
