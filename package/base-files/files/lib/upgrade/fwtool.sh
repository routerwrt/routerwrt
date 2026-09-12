# SPDX-License-Identifier: GPL-2.0-only
#
# RouterWRT fwtool image verification
#
# Requires:
#   /lib/json.sh
#   fwtool
#   ucert       (only when image signatures are enabled)
#
# Does NOT require:
#   jshn
#   libubox
#   libblobmsg-json
#   json-c
#   UCI
#   OPKG
#

. /lib/json.sh

FWTOOL_META=/tmp/sysupgrade.meta
FWTOOL_META_PARSED=/tmp/sysupgrade.meta.parsed
FWTOOL_UCERT=/tmp/sysupgrade.ucert

# Firmware signing keys are deliberately separate from APK package keys.
IMAGE_KEY_DIR="${IMAGE_KEY_DIR:-/etc/routerwrt/keys}"

# RouterWRT configuration compatibility version.
#
# This is deliberately not UCI.
#
# The file should contain simply:
#
#   1.0
#
COMPAT_VERSION_FILE="${COMPAT_VERSION_FILE:-/etc/routerwrt/compat_version}"


#
# Read one scalar value from parsed json.sh output.
#
# Input:
#   $1 = JSON path without leading slash
#
# Example:
#   fwtool_json_get compat_version
#
# json.sh output looks like:
#
#   /compat_version string 1.0
#   /compat_message string Some message here
#
fwtool_json_get()
{
	local wanted="/$1"
	local path type value

	while IFS=' ' read -r path type value; do
		[ "$path" = "$wanted" ] || continue

		case "$type" in
			string|number|boolean|null)
				printf '%s\n' "$value"
				return 0
				;;
		esac
	done < "$FWTOOL_META_PARSED"

	return 1
}


#
# Check whether a device occurs in a JSON array.
#
# Input:
#   $1 = array name
#   $2 = normal board name
#   $3 = optional OEM board name
#
# Example JSON:
#
#   "supported_devices": [
#       "dlink,dir-615-d",
#       "foo,bar"
#   ]
#
# becomes:
#
#   /supported_devices/0 string dlink,dir-615-d
#   /supported_devices/1 string foo,bar
#
fwtool_json_device_match()
{
	local prefix="/$1/"
	local device="$2"
	local oem="$3"
	local path type value

	while IFS=' ' read -r path type value; do
		case "$path" in
			"$prefix"*)
				[ "$type" = "string" ] || continue

				[ "$value" = "$device" ] && return 0
				[ -n "$oem" ] &&
					[ "$value" = "$oem" ] &&
					return 0
				;;
		esac
	done < "$FWTOOL_META_PARSED"

	return 1
}


#
# Determine whether the match was specifically against the OEM name.
#
# This matters because RouterWRT/OpenWrt configuration must not be carried
# into an OEM firmware image.
#
fwtool_json_oem_match()
{
	local prefix="/$1/"
	local oem="$2"
	local path type value

	[ -n "$oem" ] || return 1

	while IFS=' ' read -r path type value; do
		case "$path" in
			"$prefix"*)
				[ "$type" = "string" ] || continue
				[ "$value" = "$oem" ] && return 0
				;;
		esac
	done < "$FWTOOL_META_PARSED"

	return 1
}


#
# Print supported device names for diagnostics.
#
fwtool_print_supported_devices()
{
	local prefix="/$1/"
	local path type value
	local devices="Supported devices:"

	while IFS=' ' read -r path type value; do
		case "$path" in
			"$prefix"*)
				[ "$type" = "string" ] || continue
				devices="$devices $value"
				;;
		esac
	done < "$FWTOOL_META_PARSED"

	v "$devices"
}


fwtool_check_signature()
{
	[ $# -eq 1 ] || return 1

	#
	# Signature verification is optional unless explicitly required.
	#
	if [ ! -x /usr/bin/ucert ]; then
		[ "$REQUIRE_IMAGE_SIGNATURE" = 1 ] && {
			v "Image signature verification required, but ucert is unavailable"
			return 1
		}

		return 0
	fi

	#
	# Extract signature certificate.
	#
	if ! fwtool -q -s "$FWTOOL_UCERT" "$1"; then
		v "Image signature not present"

		if [ "$REQUIRE_IMAGE_SIGNATURE" = 1 ]; then
			[ "$FORCE" != 1 ] &&
				v "Use sysupgrade -F to override this check when flashing an unsigned image"

			return 1
		fi

		return 0
	fi

	#
	# A signature exists, so verify it.
	#
	# Firmware image keys are intentionally separate from APK package keys.
	#
	[ -d "$IMAGE_KEY_DIR" ] || {
		v "Firmware key directory $IMAGE_KEY_DIR not found"
		return 1
	}

	fwtool -q -T -s /dev/null "$1" |
		ucert -V -m - \
			-c "$FWTOOL_UCERT" \
			-P "$IMAGE_KEY_DIR"

	return $?
}


fwtool_check_image()
{
	local image="$1"
	local device oem
	local devicecompat imagecompat compatmessage
	local supported
	local oem_match=0

	[ $# -eq 1 ] || return 1

	rm -f "$FWTOOL_META" "$FWTOOL_META_PARSED"

	#
	# Extract fwtool metadata.
	#
	if ! fwtool -q -i "$FWTOOL_META" "$image"; then
		v "Image metadata not present"

		if [ "$REQUIRE_IMAGE_METADATA" = 1 ]; then
			[ "$FORCE" != 1 ] &&
				v "Use sysupgrade -F to override this check when flashing an image without metadata"

			return 1
		fi

		return 0
	fi

	#
	# Parse/validate JSON.
	#
	# json.sh outputs a flat list which lets the rest of this file remain
	# ordinary shell code instead of recreating the jshn state machine.
	#
	if ! json < "$FWTOOL_META" > "$FWTOOL_META_PARSED"; then
		v "Invalid image metadata"
		rm -f "$FWTOOL_META_PARSED"
		return 1
	fi

	#
	# Current device identity.
	#
	if [ ! -s /tmp/sysinfo/board_name ]; then
		v "Unable to determine board name"
		return 1
	fi

	device="$(cat /tmp/sysinfo/board_name)"

	#
	# Some OEM images use their own short board identifier.
	#
	if [ -s /tmp/sysinfo/oem_name ]; then
		oem="$(cat /tmp/sysinfo/oem_name)"
	else
		oem=
	fi

	#
	# RouterWRT configuration compatibility version.
	#
	# No UCI dependency. A missing file means legacy/default 1.0.
	#
	if [ -s "$COMPAT_VERSION_FILE" ]; then
		devicecompat="$(cat "$COMPAT_VERSION_FILE")"
	else
		devicecompat="1.0"
	fi

	#
	# Image compatibility metadata.
	#
	imagecompat="$(fwtool_json_get compat_version)"
	compatmessage="$(fwtool_json_get compat_message)"

	[ -n "$imagecompat" ] || imagecompat="1.0"

	#
	# OpenWrt convention:
	#
	#   compat 1.0 -> supported_devices
	#   later ABI -> new_supported_devices
	#
	if [ "$imagecompat" = "1.0" ]; then
		supported="supported_devices"
	else
		supported="new_supported_devices"
	fi

	#
	# Board must occur in the appropriate supported-device array.
	#
	if ! fwtool_json_device_match "$supported" "$device" "$oem"; then
		v "Device $device not supported by this image"
		fwtool_print_supported_devices "$supported"
		return 1
	fi

	#
	# Remember whether this matched the OEM identity specifically.
	#
	if fwtool_json_oem_match "$supported" "$oem"; then
		oem_match=1
	fi

	#
	# A major compatibility version change is never safe for sysupgrade.
	#
	if [ "${devicecompat%.*}" != "${imagecompat%.*}" ]; then
		v "The device is supported, but this image is incompatible for sysupgrade based on the image version ($devicecompat->$imagecompat)."

		[ -n "$compatmessage" ] &&
			v "$compatmessage"

		return 1
	fi

	#
	# A minor compatibility change means the firmware may be flashed,
	# but existing RouterWRT configuration must not be restored.
	#
	# Matching an OEM identity is treated the same way: RouterWRT/OpenWrt
	# configuration and OEM configuration are different configuration ABIs.
	#
	if [ "$SAVE_CONFIG" = 1 ] &&
	   { [ "${devicecompat#*.}" != "${imagecompat#*.}" ] ||
	     [ "$oem_match" = 1 ]; }; then

		[ "$IGNORE_MINOR_COMPAT" = 1 ] &&
			return 0

		if [ "$oem_match" = 1 ]; then
			v "The device is supported, but RouterWRT configuration cannot be preserved when flashing OEM firmware. Please use sysupgrade -n."
		else
			v "The device is supported, but the config is incompatible with the new image ($devicecompat->$imagecompat). Please upgrade without keeping config (sysupgrade -n)."
		fi

		[ -n "$compatmessage" ] &&
			v "$compatmessage"

		return 1
	fi

	return 0
}
