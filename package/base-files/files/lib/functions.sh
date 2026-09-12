# Copyright (C) 2006-2014 OpenWrt.org
# Copyright (C) 2006 Fokus Fraunhofer <carsten.tittel@fokus.fraunhofer.de>
# Copyright (C) 2010 Vertical Communications

include() {
	local file

	for file in "$1"/*.sh; do
		[ -f "$file" ] && . "$file"
	done
}

find_mtd_index() {
	local PART="$(grep "\"$1\"" /proc/mtd | awk -F: '{print $1}')"
	local INDEX="${PART##mtd}"

	echo ${INDEX}
}

find_mtd_part() {
	local INDEX=$(find_mtd_index "$1")
	local PREFIX=/dev/mtdblock

	[ -d /dev/mtdblock ] && PREFIX=/dev/mtdblock/
	echo "${INDEX:+$PREFIX$INDEX}"
}

board_name() {
	[ -e /tmp/sysinfo/board_name ] && cat /tmp/sysinfo/board_name || echo "generic"
}

cmdline_get_var() {
	local var=$1
	local cmdlinevar tmp

	for cmdlinevar in $(cat /proc/cmdline); do
		tmp=${cmdlinevar##${var}}
		[ "=" = "${tmp:0:1}" ] && echo ${tmp:1}
	done
}

add_group_and_user() {
	[ -z "$pkgname" ] && local pkgname="$(basename ${1%.*})"
	local rusers="$(sed -ne 's/^Require-User: *//p' $root/usr/lib/opkg/info/${pkgname}.control 2>/dev/null)"
	if [ -f "$root/lib/apk/packages/${pkgname}.rusers" ]; then
		local rusers="$(cat $root/lib/apk/packages/${pkgname}.rusers)"
	fi

	if [ -n "$rusers" ]; then
		local tuple oIFS="$IFS"
		for tuple in $rusers; do
			local uid gid uname gname addngroups addngroup addngname addngid

			IFS=":"
			set -- $tuple; uname="$1"; gname="$2"; addngroups="$3"
			IFS="="
			set -- $uname; uname="$1"; uid="$2"
			set -- $gname; gname="$1"; gid="$2"
			IFS="$oIFS"

			if [ -n "$gname" ] && [ -n "$gid" ]; then
				group_exists "$gname" || group_add "$gname" "$gid"
			elif [ -n "$gname" ]; then
				gid="$(group_add_next "$gname")"
			fi

			if [ -n "$uname" ]; then
				user_exists "$uname" || user_add "$uname" "$uid" "$gid"
			fi

			if [ -n "$uname" ] && [ -n "$gname" ]; then
				group_add_user "$gname" "$uname"
			fi

			if [ -n "$uname" ] &&  [ -n "$addngroups" ]; then
				oIFS="$IFS"
				IFS=","
				for addngroup in $addngroups ; do
					IFS="="
					set -- $addngroup; addngname="$1"; addngid="$2"
					if [ -n "$addngid" ]; then
						group_exists "$addngname" || group_add "$addngname" "$addngid"
					else
						group_add_next "$addngname"
					fi

					group_add_user "$addngname" "$uname"
				done
				IFS="$oIFS"
			fi

			unset uid gid uname gname addngroups addngroup addngname addngid
		done
	fi
}

default_postinst() {
	local root="${IPKG_INSTROOT}"
	[ -z "$pkgname" ] && local pkgname="$(basename ${1%.*})"
	local filelist="${root}/usr/lib/opkg/info/${pkgname}.list"
	[ -f "$root/lib/apk/packages/${pkgname}.list" ] && filelist="$root/lib/apk/packages/${pkgname}.list"
	local ret=0

	if [ -e "${root}/usr/lib/opkg/info/${pkgname}.list" ]; then
		filelist="${root}/usr/lib/opkg/info/${pkgname}.list"
		add_group_and_user "${pkgname}"
	fi

	if [ -e "${root}/lib/apk/packages/${pkgname}.alternatives" ]; then
		update_alternatives install "${pkgname}"
	fi

	if [ -d "$root/rootfs-overlay" ]; then
		cp -R $root/rootfs-overlay/. $root/
		rm -fR $root/rootfs-overlay/
	fi

	if [ -z "$root" ]; then
		if grep -m1 -q -s "^/etc/modules.d/" "$filelist"; then
			kmodloader
		fi

		if grep -m1 -q -s "^/etc/sysctl.d/" "$filelist"; then
			/etc/init.d/sysctl restart
		fi

		if grep -m1 -q -s "^/etc/uci-defaults/" "$filelist"; then
			[ -d /tmp/.uci ] || mkdir -p /tmp/.uci
			for i in $(grep -s "^/etc/uci-defaults/" "$filelist"); do
				( [ -f "$i" ] && cd "$(dirname $i)" && . "$i" ) && rm -f "$i"
			done
			uci commit
		fi

		rm -f /tmp/luci-indexcache.*
	fi

	if [ -f "$root/usr/lib/opkg/info/${pkgname}.postinst-pkg" ]; then
		( . "$root/usr/lib/opkg/info/${pkgname}.postinst-pkg" )
		ret=$?
	fi

	local shell="$(command -v bash)"
	for i in $(grep -s "^/etc/init.d/" "$filelist"); do
		if [ -n "$root" ]; then
			${shell:-/bin/sh} "$root/etc/rc.common" "$root$i" enable
		else
			if [ "$PKG_UPGRADE" != "1" ]; then
				"$i" enable
			fi
			"$i" start
		fi
	done

	return $ret
}


