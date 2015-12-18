#!/bin/bash

if [[ "$0" =~ "$BASH_SOURCE" ]] ; then
    echo "$BASH_SOURCE should be included from another script, not directly called."
    exit 1
fi

PAGETYPES=$KERNEL_SRC/tools/vm/page-types
if [ ! -x "${PAGETYPES}" ] || [ ! -s "${PAGETYPES}" ] ; then
    make clean -C $KERNEL_SRC/tools > /dev/null 2>&1
    echo -n "build KERNEL_SRC/tools ... "
    make vm -C $KERNEL_SRC/tools > /dev/null 2>&1 && echo "done" || echo "failed"
fi
[ ! -x "${PAGETYPES}" ] && echo "${PAGETYPES} not found." >&2 && exit 1

GUESTPAGETYPES=/usr/local/bin/page-types
MCEINJECT=$(dirname $(readlink -f $BASH_SOURCE))/mceinj.sh

all_unpoison() { $PAGETYPES -b hwpoison -x -N; }

get_HWCorrupted() { grep "HardwareCorrupted" /proc/meminfo | tr -s ' ' | cut -f2 -d' '; }
save_nr_corrupted_before() { get_HWCorrupted   > ${TMPF}.hwcorrupted1; }
save_nr_corrupted_inject() { get_HWCorrupted   > ${TMPF}.hwcorrupted2; }
save_nr_corrupted_unpoison() { get_HWCorrupted > ${TMPF}.hwcorrupted3; }
save_nr_corrupted() { get_HWCorrupted > ${TMPF}.hwcorrupted"$1"; }
show_nr_corrupted() {
    if [ -e ${TMPF}.hwcorrupted"$1" ] ; then
        cat ${TMPF}.hwcorrupted"$1" | tr -d '\n'
    else
        echo -n 0
    fi
}

# if accounting corrupted, "HardwareCorrupted" value could be very large
# number, which bash cannot handle as numerical values. So we do here
# comparation as string
__check_nr_hwcorrupted() {
    count_testcount
    if [ "$(show_nr_corrupted 1)" == "$(show_nr_corrupted 2)" ] ; then
        count_failure "hwpoison inject didn't raise \"HardwareCorrupted\" value ($(show_nr_corrupted 1) -> $(show_nr_corrupted 2))"
    elif [ "$(show_nr_corrupted 1)" != "$(show_nr_corrupted 3)" ] ; then
        count_failure "accounting \"HardwareCorrupted\" did not back to original value ($(show_nr_corrupted 1) -> $(show_nr_corrupted 2) -> $(show_nr_corrupted 3))"
    else
        count_success "accounting \"HardwareCorrupted\" was raised and reduced back to original value ($(show_nr_corrupted 1) -> $(show_nr_corrupted 2) -> $(show_nr_corrupted 3))"
    fi
}

__check_nr_hwcorrupted_consistent() {
    count_testcount
    if [ "$(show_nr_corrupted 1)" == "$(show_nr_corrupted 3)" ] ; then
        count_success "accounting \"HardwareCorrupted\" consistently."
    else
        count_failure "accounting \"HardwareCorrupted\" did not back to original value ($(show_nr_corrupted 1) -> $(show_nr_corrupted 3))"
    fi
}

check_nr_hwcorrupted() {
	if [ "${TMPF}.hwcorrupted2" ] ; then
		__check_nr_hwcorrupted
	else
		__check_nr_hwcorrupted_consistent
	fi
}

BASEVFN=0x700000000

if ! lsmod | grep mce_inject > /dev/null ; then
    modprobe mce_inject
fi

if ! lsmod | grep hwpoison_inject > /dev/null ; then
    modprobe hwpoison_inject
fi

check_install_package expect
check_install_package ruby

if ! which mce-inject > /dev/null || [[ ! -s "$(which mce-inject)" ]] ; then
    echo "No mce-inject installed."
    check_install_package bison
    check_install_package flex
    # http://git.kernel.org/cgit/utils/cpu/mce/mce-inject.git
    rm -rf ./mce-inject
    git clone https://github.com/Naoya-Horiguchi/mce-inject
    pushd mce-inject
    make
    make install
    popd
fi

# clear all poison pages before starting test
all_unpoison
echo 0 > /proc/sys/vm/memory_failure_early_kill
