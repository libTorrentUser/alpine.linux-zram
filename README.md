# alpine-linux-zram
Create custom Alpine Linux live images with the root file system mounted on ZRAM and with a custom start-up script.

Just follow these steps
- setup an abuild user and clone the aports repository, just like it is described in the wiki. You can use the scripts/init-aports.sh if you are feeling lazy.
- copy the files inside the aports/scripts dir to your newly cloned aports/scripts dir
- go to aports/scripts dir and run ./custom-mkimage.sh --profile=someProfile --dir=someDirYouWantCopiedOnTheLiveImage

# Startup script
If you want to insert a startup script, one way to do it is by modifying the aports/main/alpine-baselayout/inittab file inside the cloned aports repository and tell it to run your script when the system boots. See the file scripts/aports.diff if you want to know how I did it. And if you choose to do the same, remember you must rebuild the alpine-baselayout package in order to use. And don't forget to bump the version, otherwise the scripts will use the default package.

To rebuild the package after chaning it:
- cd into to aports/main/alpine-baselayoyt
- run abuild checksum
- run abuild

The pacakge will be built into your local repository. The file /etc/abuild.conf will give you the location. Make sure that the custom-mkimage.sh script is using that directory. By default, custom-mkimage.sh will use /tmp/aports/packages/ so, if your local repository path is set to anything else, either change it inside custom-mkimage.sh or change it on /etc/abuild.conf

