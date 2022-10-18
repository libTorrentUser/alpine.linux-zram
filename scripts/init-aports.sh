#!/bin/sh

# you should probably specify a stable aports branch, like "3.16-stable". If you
# leave it empty, this script will clone the master branch. And the master 
# branch, sometimes, has a bunch of problems
_branch="${1:-master}";

# print something and exit the script
Die()
{
	printf >&2 -- '%s\n' "$*";
	exit 1;
}


# check the result of a command and exit the script if it failed
DieIfFails()
{
	"$@" || Die "cannot $*"; 
}


# add the required packages
DieIfFails apk add alpine-sdk build-base apk-tools alpine-conf busybox fakeroot syslinux xorriso squashfs-tools sudo grub-efi xz

# create the "build" user
if ! id -u build >> /dev/null; then
	DieIfFails adduser -D -G abuild build ;
	DieIfFails echo 'build:build' | chpasswd;
	echo "%abuild ALL=(ALL) ALL" > /etc/sudoers.d/abuild;
fi

# generete the keys and clone the aports repository. The call to abuild-sign
# is checking if the user already has a PK. If that is the case, then we assume
# abuild-keygen has already been called
DieIfFails su - build -c "\
\
abuild-sign --installed || abuild-keygen -i -a -n; \
\
printf 'cloning aports %s\n' $_branch; \
git clone --depth=1 -b $_branch https://gitlab.alpinelinux.org/alpine/aports.git;"

# end the script and the build user, because he is the one we should use to
# build stuff
DieIfFails su - build;
