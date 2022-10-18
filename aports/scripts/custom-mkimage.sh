#!/bin/sh

# creates a live Alpine Linux image that will mount the rootfs on zram
# 
# usage 
# custom-mkimage.sh --profile=profile --directory=dir [--packages="p1 p2 ..."]
#
#
# ex:
#
# build a live ISO containing the dir /my/dir/ using the profile custom_virt
# custom-mkimage.sh --profile=custom_virt --directory=/my/dir
#
# same as above, but include the dwm and mpv packages
# custom-mkimage.sh --profile=custom_virt --directory=/my/dir --packages="dwm mpv"
#
# NOTE: the --packages option will only work on profiles contained in the 
# mkimg.custom.sh file. If you wish to use it with other profiles, take a look
# at how it is done on the "custom" profiles and copy the code to yours.


_profile=;
_directory=;
_packages=;
_zram=1;


_buildDir='/tmp/aports';
_sysScriptDir="${_buildDir}/scripts";



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


ParseCommandLine()
{
	for i in "$@"; do
		case $i in			 			
			--directory=*)
				_directory="${i#*=}";
				shift;
	      	;;
	      	-h|--help)
	      		PrintUsage;
	      	;;	    
			--packages=*)
				_packages="${i#*=}";
				shift;
	      	;;
	      	--profile=*)
	      		_profile="${i#*=}";
	      		shift;
	      	;;
			--)
	      		# nothing else to parse
	      		shift;
	      		break;  
	      	;;    
	    	*)
	      		Die "Unknown option \"$i\""
				exit 1;
	      	;;
		esac
	done
}



# first we ensure our customized version of alpine-baselayout is built. The
# modified inittab file is there, and it is pretty much the most important 
# change we made. It is the inittab file the one that calls the user defined
# initialization script (the ali/init.sh file)
#cd ../main/alpine-baselayout
#abuild

UpdatePath()
{
	DieIfFails mkdir -p "$_sysScriptDir";
	PATH="${_sysScriptDir}:$PATH";
}


# mkimage.sh, the standard Alpine Linux script would should call to build 
# Alpine Linux ISOs,  will call /sbin/update-kernel to generate the kernel and 
# the initfs. But, currently, mkimage.sh does not allow us to pass a couple of
# useful paramters to update-kernel. Another problem is that the update-kernel
# script will call mkinitfs but it does not allow us to call it using some
# parameters we need to use.
#
# In order to solve all that we will copy the update-kernel script so we can 
# change it at will. We will then update $PATH to ensure that our copy is used
# instead when using this script (see UpdatePath()).
ModifyUpdateKernel()
{
	DieIfFails cp "/sbin/update-kernel" "${_sysScriptDir}";

	# update /sbin/update-kernel so we can pass aditional compression options to the
	# mkquashfs call that will be done when generating the ISO
	#sudo sed -i 's/-comp xz -exit-on-error/-comp xz \$_alpinoSquashFsOptions -exit-on-error/' /sbin/update-kernel
	#export _alpinoSquashFsOptions="-b 1M -Xdict-size 100% -Xbcj x86";	
	DieIfFails sed -i 's/-comp xz -exit-on-error/-comp xz -b 1M -Xdict-size 100% -Xbcj x86 -exit-on-error/' "${_sysScriptDir}/update-kernel";

	# the user can pass "features" to the mkinitfs script so he can access that
	# stuff when the initfs is loaded during boot. Those "features" are files 
	# that contain modules and files that will be copied to initramfs.
	#
	# When the mkinitfs script is executed, it will search for files named 
	# "feature.modules" and "feature.files" inside the mkinitfs features 
	# directory (default is "/etc/mkinitfs.d/features.d", but we add another one
	# to the list - see ModifyMkinitfs()).
	#
	# The kernel modules inside the .modules files will be simply copied to the
	# initramfs, but the files inside the .files files will not. The only way to
	# make those files available inside initramfs seems to be to also pass a 
	# list of packages that contains them to the update-kernel script. The 
	# update-kernel script will then extract those packages inside a temporary 
	# directory and the mkinitfs script will then search for the files there, in
	# that temp directory, and only if it finds the file there it will copy 
	# them to the initfs.
	#
	# If you do not provide the package, mkinitfs will not find the files and
	# will simply ignore them.
	#
	# Although the mkimage.sh script allows the user to pass this list of 
	# packages, using a variable named "kernel_addons" in the profile_xxxx()
	# function, it will add a "kernel-flavor" suffix to the values before 
	# passing them to the update-kernel script (which is the one who fecthes and
	# extracts the packages). That suffix will (probably) cause the package to
	# not be found because, for instance, there is an "e2fsprogs" package in the
	# repositories, but there isn't an "e2fsprogs-vanilla" or "e2fsprogs-virt"
	# package.
	#
	# Because of all that, we have to modify our local copy of update-kernel
	# and manually add the packages we need there
	if [ -n  "$_zram" ]; then
		# add the e2fsprogs package because we will put an ext4 file system
		# in the zram device where we will put the system root
		sed -i 's;_apk add --no-scripts alpine-base \$PACKAGES;& e2fsprogs;' "${_sysScriptDir}/update-kernel";
	fi
}


# copy and modify mkinitfs, as described in the comments of ModifyUpdateKernel()
ModifyMkinitfs()
{
	DieIfFails cp "/sbin/mkinitfs" "${_sysScriptDir}";

	# change comoopression to xz. We also disable multi-threading since it 
	# seems to produce slightly smaller files. You can add -T 0 (or -T threads)
	# again if you wish to test it out (-T 0 means all available core/threads)
	DieIfFails sed -i 's;initfscomp=gzip;initfscomp=xz;'  "${_sysScriptDir}/mkinitfs";
	DieIfFails sed -i 's;xz -C crc32 -T 0;xz -9e -C crc32;' "${_sysScriptDir}/mkinitfs";

	# if the user wants to mount the root filesytem on a zram device (which is
	# awesome), we will have to force mkinitfs to use a modified version of 
	# initramfs-init. 
	if [ -n "$_zram" ]; then			
		local mkinitfsDir="${_sysScriptDir}/mkinitfs.d";	
	
		# the zram module is not part of the default "feautures" of mkinitfs.
		# We have to add it there otherwise the module won't be inclused inside
		# the initramfs and the system will crash when we try to load it using
		# the code below (SysRootToZRAM())		

		# in order to avoid messing with the system, we will create a temporary
		# features directory and write the features we need there
		local featuresDir="${mkinitfsDir}/features.d";
		DieIfFails mkdir -p "$featuresDir";

		# and now hard-code that dir into mkinitfs search path
		DieIfFails sed -i 's!features_dirs=\$.*!&\nfeatures_dirs="'"${featuresDir}"' \$features_dirs"!' "${_sysScriptDir}/mkinitfs";		
		
		if [ ! -e "/etc/mkinitfs/features.d/zram.modules" ]; then
			# since there is no zram.modules file in the standard features
			# directory, we create our own and add our directory to the list of
			# directories mkinitfs will search for features. The only problem
			# is that, although the mkinitfs script is prepared to receive that
			# directory as an argument, we do not call it directly. It gets 
			# called by the update-kernel script, and there is no way to pass
			# the directory to that one so it can forward to mkinitfs. So, 
			# because of that, we have modify our local mkinitfs copy again and 
			# hard-code the directory right in there
			DieIfFails printf 'kernel/drivers/block/zram/zram.ko' > "${featuresDir}/zram.modules";			
		fi

		# since we will mount an ext4 file system on top of our zram device, we
		# need the mkfs files in there too. 
		#
		# IMPORTANT: simply specifying these files here will not make them 
		# available inside the initramfs. The package(s) containing them must
		# be passed to update-kernel. See ModifyUpdateKernel() for more info
		if [ ! -e "/etc/mkinitfs/features.d/ext4.files" ]; then
			printf '/sbin/mke2fs\n/sbin/mkfs.ext4' > "${featuresDir}/ext4.files";
		fi

		# force the zram and ext4 features to always be included
		DieIfFails sed -i 's;\( features="\)\(.*\);\1zram ext4 \2;' "${_sysScriptDir}/mkinitfs";
	
		# force (our) mkinitfs to use our own mkinitfs-in					
		DieIfFails cp "/usr/share/mkinitfs/initramfs-init" "$mkinitfsDir";
		DieIfFails sed -i 's;init="$datadir"/initramfs-init;init='"${mkinitfsDir}/initramfs-init"';' "${_sysScriptDir}/mkinitfs";

		# remove this from mkinitfs-in because we will no longer using tmpfs on
		# the root file system. We'll be using ext4 (on zram) and "mode=xxx" is
		# not a valid ext4 mount option
		sed -i 's;rootflags="mode=0755";rootflags=;'  "${mkinitfsDir}/initramfs-init"

		# and update it so it creates a zram device and mounts the
		# root file system on it
		local commands=$(cat <<'__ModifyMkinitfs_HereDocLimitString__'
		
SysRootToZRAM()
{	
	ebegin 'SysRootToZRAM'
	
	# get how much is 85% of the available RAM, in MB.
	# That will be the limit of our zram disk will be
	# able to use. And the zram disk size will be 2x
	# that ammount
	local _totalRAMinKB=$(awk 'NR==3{ print $2; exit }' /proc/meminfo)

	local _zramMemLimitInMB=$( echo $_totalRAMinKB | awk '{ printf("%d"), $1 / 1024 * .85 }' )

	local _zramDiskSizeInMB=$(($_zramMemLimitInMB * 2))

	# setup the zram device
	modprobe zram num_devices=1
	echo zstd > /sys/block/zram0/comp_algorithm
	echo "${_zramDiskSizeInMB}M" > /sys/block/zram0/disksize
	echo "${_zramMemLimitInMB}M" > /sys/block/zram0/mem_limit
			
	# remove invalid ext mount options
	rootflags="${rootflags#mode=*,}";

	# and add some useful (and needed) ones
	rootflags="${rootflags:+${rootflags},}noatime,discard";	
	printf 'rootflags=%s\\n' "${rootflags}"; 

	# mount our zram device on the sysroot dir								
	mkfs.ext4 -m 0 -O ^has_journal /dev/zram0
	mount -t ext4 -o $rootflags /dev/zram0 $sysroot

	# change the mode to 0755, which is what the original initramfs-init did
	chmod 0755 $sysroot

	eend $?
}

# mount -t tmpfs -o $rootflags tmpfs $sysroot
SysRootToZRAM;

__ModifyMkinitfs_HereDocLimitString__
			);

		# update our initramfs-init copy with the new one that has the code 
		# above
		local updatedDoc=;
		updatedDoc=$(awk -v x="$commands" '{sub(/mount -t tmpfs -o \$rootflags tmpfs \$sysroot/, x); print;}' "${mkinitfsDir}/initramfs-init");
		if [ $? -ne 0 ]; then
			Die 'call to awk failed';
		fi;
		
		printf '%s' "$updatedDoc" > "${mkinitfsDir}/initramfs-init"
	fi;
}


Execute()
{
	printf 'profile: %s
directory: %s
packages: %s
zram: %i\n' \
"$_profile" \
"$_directory" \
"$_packages" \
"$_zram";


	# get the version and then extract only the major.minor digits, because that is
	# what goes inside the official repositories URLs
	#_version=$(grep 'pkgver=' ../alpine-base/APKBUILD)
	#_version=$(echo $_version | sed 's/.*=\([0-9]\+.[0-9]\+\).*/\1/')

	# and now use that version to create the URL
	#_officialRepositoryURL="http://dl-cdn.alpinelinux.org/alpine/v${_version}"
	_officialRepositoryURL="http://dl-cdn.alpinelinux.org/alpine/latest-stable"

	# clean the work dir (sudo is needed because some files are owned by root)
	DieIfFails sudo rm -rf "${_buildDir}/work";

	# finally, build the live image
	#cd ../../scripts
	CUSTOM_DIR="$_directory" CUSTOM_APKS="$_packages" ./mkimage.sh \
		--profile "$_profile" \
		--outdir "${_buildDir}/iso" \
		--workdir "${_buildDir}/work" \
		--repository "${_buildDir}/packages/main" \
		--repository "${_officialRepositoryURL}/main" \
		--repository "${_officialRepositoryURL}/community" \
		--arch x86_64
}


ParseCommandLine "$@";
UpdatePath;
ModifyUpdateKernel;
ModifyMkinitfs;
Execute;
