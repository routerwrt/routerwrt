# SPDX-License-Identifier: GPL-2.0-only
#
# RouterWRT generic sysupgrade helpers
#

RAM_ROOT=/tmp/root

# Configuration archive extracted by preinit after upgrade
export BACKUP_FILE=sysupgrade.tgz


#
# RAM-root construction
#

[ -x /usr/bin/ldd ] || ldd() {
	LD_TRACE_LOADED_OBJECTS=1 "$@"
}

libs() {
	ldd "$@" 2>/dev/null |
		sed -E 's/(.* => )?(.*) .*/\2/'
}

install_file() { # <file> [ <file> ... ]
	local file target dest dir

	for file in "$@"; do
		if [ -L "$file" ]; then
			target="$(readlink -f "$file")"
			dest="$RAM_ROOT/$file"

			[ -e "$dest" ] || {
				dir="$(dirname "$dest")"
				mkdir -p "$dir"
				ln -s "$target" "$dest"
			}

			file="$target"
		fi

		dest="$RAM_ROOT/$file"

		[ -f "$file" ] && [ ! -f "$dest" ] && {
			dir="$(dirname "$dest")"
			mkdir -p "$dir"
			cp "$file" "$dest"
		}
	done
}

install_bin() { # <binary>
	local src files

	src="$1"
	files="$src"

	[ -x "$src" ] &&
		files="$src $(libs "$src")"

	install_file $files
}


#
# Generic hook support
#

run_hooks() { # <argument> <function> [ <function> ... ]
	local arg="$1"
	shift

	for func in "$@"; do
		eval "$func \"\$arg\""
	done
}


#
# Interactive confirmation
#

ask_bool() {
	local default="$1"
	local answer

	shift
	answer="$default"

	[ "$INTERACTIVE" = 1 ] && {
		case "$default" in
			0)
				printf "%s (y/N): " "$*"
				;;
			*)
				printf "%s (Y/n): " "$*"
				;;
		esac

		read -r answer

		case "$answer" in
			y|Y|yes|YES)
				answer=1
				;;
			n|N|no|NO)
				answer=0
				;;
			*)
				answer="$default"
				;;
		esac
	}

	[ "$answer" -gt 0 ]
}


#
# Logging
#

_v() {
	[ -n "$VERBOSE" ] &&
	[ "$VERBOSE" -ge 1 ] &&
		echo "$*" >&2
}

v() {
	_v "$(date) upgrade: $*"

	# logger is optional in RouterWRT.
	# If BusyBox logger is enabled, also send upgrade messages to syslog.
	command -v logger >/dev/null 2>&1 &&
		logger -p info -t upgrade "$*"
}


#
# Filesystem helpers
#

rootfs_type() {
	/bin/mount |
		awk '($3 == "/") && ($5 !~ /rootfs/) { print $5; exit }'
}


#
# Image access
#

get_image() { # <source> [ <command> ]
	local from="$1"
	local cmd="$2"
	local magic

	if [ -z "$cmd" ]; then
		magic="$(
			dd if="$from" bs=2 count=1 2>/dev/null |
				hexdump -n 2 -e '1/1 "%02x"'
		)"

		case "$magic" in
			1f8b)
				cmd="busybox zcat"
				;;
			*)
				cmd="cat"
				;;
		esac
	fi

	$cmd < "$from"
}

get_image_dd() {
	local from="$1"
	shift

	(
		exec 3>&2

		(
			exec 3>&2
			get_image "$from" 2>&1 1>&3 |
				grep -v -F ' Broken pipe'
		) 2>&1 1>&3 |
		(
			exec 3>&2
			dd "$@" 2>&1 1>&3 |
				grep -v -E ' records (in|out)'
		) 2>&1 1>&3

		exec 3>&-
	)
}


#
# Image identification
#

get_magic_word() {
	(
		get_image "$@" |
			dd bs=2 count=1 |
			hexdump -v -n 2 -e '1/1 "%02x"'
	) 2>/dev/null
}

get_magic_long() {
	(
		get_image "$@" |
			dd bs=4 count=1 |
			hexdump -v -n 4 -e '1/1 "%02x"'
	) 2>/dev/null
}

identify_magic_long() {
	local magic="$1"

	case "$magic" in
		55424923)
			echo "ubi"
			;;
		31181006)
			echo "ubifs"
			;;
		68737173)
			echo "squashfs"
			;;
		d00dfeed)
			echo "fit"
			;;
		4349*)
			echo "combined"
			;;
		1f8b*)
			echo "gzip"
			;;
		*)
			echo "unknown $magic"
			;;
	esac
}


#
# Upgrade indication
#

indicate_upgrade() {
	[ -f /etc/diag.sh ] || return 0

	. /etc/diag.sh
	set_state upgrade
}


#
# Generic NOR / MTD firmware upgrade
#
# $1: image path
# $2: optional command used to extract/filter image
#

default_do_upgrade() {
	sync
	echo 3 > /proc/sys/vm/drop_caches

	if [ -n "$UPGRADE_BACKUP" ]; then
		get_image "$1" "$2" |
			mtd $MTD_ARGS $MTD_CONFIG_ARGS \
				-j "$UPGRADE_BACKUP" \
				write - "${PART_NAME:-image}"
	else
		get_image "$1" "$2" |
			mtd $MTD_ARGS \
				write - "${PART_NAME:-image}"
	fi

	[ $? -eq 0 ] || exit 1
}
