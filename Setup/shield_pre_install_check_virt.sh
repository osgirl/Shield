#!/bin/bash -
# virt-what.  Generated from virt-what.in by configure.
# Copyright (C) 2008-2011 Red Hat Inc.
# Do not allow unset variables, and set defaults.
set -u
root=''
skip_qemu_kvm=false
 
VERSION="1.13"
 
function fail {
    echo "virt-what: $1" >&2
    exit 1
}
 
function usage {
    echo "virt-what [options]"
    echo "Options:"
    echo "  --help          Display this help"
    echo "  --version       Display version and exit"
    exit 0
}
 
# Handle the command line arguments, if any.
 
TEMP=$(getopt -o v --long help --long version --long test-root: -n 'virt-what' -- "$@")
if [ $? != 0 ]; then exit 1; fi
eval set -- "$TEMP"
 
while true; do
    case "$1" in
	--help) usage ;;
        --test-root)
            # Deliberately undocumented: used for 'make check'.
            root="$2"
            shift 2
            ;;
	-v|--version) echo "$VERSION"; exit 0 ;;
	--) shift; break ;;
	*) fail "internal error ($1)" ;;
    esac
done
 
# Add /sbin and /usr/sbin to the path so we can find system
# binaries like dmicode.
# Add /usr/libexec to the path so we can find the helper binary.
prefix=/usr
exec_prefix=${prefix}
PATH="${root}${prefix}/lib/virt-what:${root}/sbin:${root}/usr/sbin:${PATH}"
 
# Check we're running as root.
 
if [ "x$root" = "x" ] && [ "$EUID" -ne 0 ]; then
    fail "this script must be run as root"
fi
 
# Many fullvirt hypervisors give an indication through CPUID.  Use the
# helper program to get this information.
 
cpuid=$(virt-what-cpuid-helper)
 
# Check for various products in the BIOS information.
# Note that dmidecode doesn't exist on non-PC architectures.  On these,
# this will return an error which is ignored (error message redirected
# into $dmi variable).
 
dmi=$(LANG=C dmidecode 2>&1)
 
# Architecture.
# Note for the purpose of testing, we only call uname with -p option.
 
arch=$(uname -p)
 
# Check for VMware.
# cpuid check added by Chetan Loke.
 
if [ "$cpuid" = "VMwareVMware" ]; then
    echo vmware
elif echo "$dmi" | grep -q 'Manufacturer: VMware'; then
    echo vmware
fi
 
# Check for Hyper-V.
# http://blogs.msdn.com/b/sqlosteam/archive/2010/10/30/is-this-real-the-metaphysics-of-hardware-virtualization.aspx
if [ "$cpuid" = "Microsoft Hv" ]; then
    echo hyperv
fi
 
# Check for VirtualPC.
# The negative check for cpuid is to distinguish this from Hyper-V
# which also has the same manufacturer string in the SM-BIOS data.
if [ "$cpuid" != "Microsoft Hv" ] &&
    echo "$dmi" | grep -q 'Manufacturer: Microsoft Corporation'; then
    echo virtualpc
fi
 
# Check for VirtualBox.
# Added by Laurent LÃ©onard.
if echo "$dmi" | grep -q 'Manufacturer: innotek GmbH'; then
    echo virtualbox
fi
 
# Check for OpenVZ / Virtuozzo.
# Added by Evgeniy Sokolov.
# /proc/vz - always exists if OpenVZ kernel is running (inside and outside
# container)
# /proc/bc - exists on node, but not inside container.
 
if [ -d "${root}/proc/vz" -a ! -d "${root}/proc/bc" ]; then
    echo openvz
fi
 
# Check for LXC containers
# http://www.freedesktop.org/wiki/Software/systemd/ContainerInterface
# Added by Marc Fournier
 
if [ -e "${root}/proc/1/environ" ] &&
    cat "${root}/proc/1/environ" | tr '\000' '\n' | grep -Eiq '^container='; then
    echo lxc
fi
 
# Check for Linux-VServer
if cat "${root}/proc/self/status" | grep -q "VxID: [0-9]*"; then
    echo linux_vserver
fi
 
# Check for UML.
# Added by Laurent LÃ©onard.
if grep -q 'UML' "${root}/proc/cpuinfo"; then
    echo uml
fi
 
# Check for IBM PowerVM Lx86 Linux/x86 emulator.
if grep -q '^vendor_id.*PowerVM Lx86' "${root}/proc/cpuinfo"; then
    echo powervm_lx86
fi
 
# Check for Hitachi Virtualization Manager (HVM) Virtage logical partitioning.
if echo "$dmi" | grep -q 'Manufacturer.*HITACHI' &&
   echo "$dmi" | grep -q 'Product.* LPAR'; then
    echo virtage
fi
 
# Check for IBM SystemZ.
if grep -q '^vendor_id.*IBM/S390' "${root}/proc/cpuinfo"; then
    echo ibm_systemz
    if [ -f "${root}/proc/sysinfo" ]; then
        if grep -q 'VM.*Control Program.*z/VM' "${root}/proc/sysinfo"; then
            echo ibm_systemz-zvm
        elif grep -q '^LPAR' "${root}/proc/sysinfo"; then
            echo ibm_systemz-lpar
        else
            # This is unlikely to be correct.
            echo ibm_systemz-direct
        fi
    fi
fi
 
# Check for Parallels.
if echo "$dmi" | grep -q 'Vendor: Parallels'; then
    echo parallels
    skip_qemu_kvm=true
fi
 
# Check for Xen.
 
if [ "$cpuid" = "XenVMMXenVMM" ]; then
    echo xen; echo xen-hvm
    skip_qemu_kvm=true
elif [ -f "${root}/proc/xen/capabilities" ]; then
    echo xen
    if grep -q "control_d" "${root}/proc/xen/capabilities"; then
        echo xen-dom0
    else
        echo xen-domU
    fi
    skip_qemu_kvm=true
elif [ -f "${root}/sys/hypervisor/type" ] &&
    grep -q "xen" "${root}/sys/hypervisor/type"; then
    # Ordinary kernel with pv_ops.  There does not seem to be
    # enough information at present to tell whether this is dom0
    # or domU.  XXX
    echo xen
elif [ "$arch" = "ia64" ]; then
    if [ -d "${root}/sys/bus/xen" -a ! -d "${root}/sys/bus/xen-backend" ]; then
        # PV-on-HVM drivers installed in a Xen guest.
        echo xen
        echo xen-hvm
    else
        # There is no virt leaf on IA64 HVM.  This is a last-ditch
        # attempt to detect something is virtualized by using a
        # timing attack.
        virt-what-ia64-xen-rdtsc-test > /dev/null 2>&1
        case "$?" in
            0) ;; # not virtual
            1) # Could be some sort of virt, or could just be a bit slow.
                echo virt
        esac
    fi
fi
 
# Check for QEMU/KVM.
#
# Parallels exports KVMKVMKVM leaf, so skip this test if we've already
# seen that it's Parallels.  Xen uses QEMU as the device model, so
# skip this test if we know it is Xen.
 
if ! "$skip_qemu_kvm"; then
    if [ "$cpuid" = "KVMKVMKVM" ]; then
	echo kvm
    else
        # XXX This is known to fail for qemu with the explicit -cpu
        # option, since /proc/cpuinfo will not contain the QEMU
        # string.  The long term fix for this would be to export
        # another CPUID leaf for non-accelerated qemu.
        if grep -q 'QEMU' "${root}/proc/cpuinfo"; then
	    echo qemu
	fi
    fi
fi