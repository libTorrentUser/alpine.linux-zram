# when this profile is used you can create a customized Alpine Linux live ISO
# by setting some env vars.
#
# CUSTOM_DIR
#     This directory will be copied to the root of the ISO
#
# CUSTOM_APKS
#     Extra apks that will be copied into the ISO
#
#
# NOTE: the reason we went the env var route instead of passing these values as
# some pretty arguments to a mkimage.sh call is that, by using env vars we avoid
# having to modify any other default script file which, in turn, makes it much
# easier to merge these modifications whenever Alpine Linux is updated

build_custom() {
	if [ ! -z "$CUSTOM_DIR" ]; then
		cp -ar "${CUSTOM_DIR}" "${DESTDIR}"
	fi
}


# mkimage.sh will search for all functions named "section_*" and then call them
# when building the profile. Here is where we will call build_custom(), which
# will copy the dir CUSTOM_DIR to the final ISO.
#
# It is very important to format this function name exactly like this! There 
# must be a space after the parenthesis, the curly brace must be on the same 
# line as the function name and there must be nothing after the brace. Not even
# spacing chars! See the function load_plugins() in mkimage.sh to see the reason
# why all that is required
section_custom() {
	build_section custom
}


profile_custom() {
	title="Custom"
	desc="Alpine Linux with custom packages."
	profile_base
	profile_abbrev="custom"
	image_ext="iso"
	arch="x86_64"
	output_format="iso"
	apks="$apks $CUSTOM_APKS"
}


profile_custom_virt() {
	profile_custom	
	kernel_flavors="virt"
	apks="$apks $CUSTOM_APKS" 
}


profile_custom_mpv() {
	title="Custom mpv"
	desc="Alpine Linux with mpv"
	profile_base
	profile_abbrev="custom"
	image_ext="iso"
	arch="x86_64"
	output_format="iso"
	apks="$apks $CUSTOM_APKS \
		xorg-server xf86-input-libinput eudev xf86-video-amdgpu xf86-video-intel xf86-video-qxl xf86-video-modesetting xset xsetroot \
		mesa-dri-gallium mesa-egl setxkbmap dwm ttf-freefont font-noto-cjk \
		p7zip \
		alsa-utils alsa-lib alsaconf \
		wireless-tools wpa_supplicant \
		openssh openssh-client openssh-server ntfs-3g rdesktop"
}


