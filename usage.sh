# Example usage in clean qemu environment
#
# $ qemu-kvm \
# $     -m 10G \
# $     -smp 6 \
# $     -kernel vmlinuz \
# $     -initrd initramfs \
# $     -net nic,model=virtio \
# $     -net user \
# $     -nographic \
# $     -append console=ttyS0

# Which is ofcourse, useless without me supplying 
# the vmlinuz and initramfs files.
# Creation of the initramfs is sill a manual task
# It does some things atypical to a standard distro initramfs.
#   - Only a kernel and initramfs are supplied to qemu, there
#     is no stateful disk image.
#   - The root= kernel cmdline is set inside the initramfs,
#     not supplied to qemu's "-append".
#   - The VM uses a lot of RAM. All writes are directed
#     towards an RAM backed AUFS rootfs.
#   - QEMU User networking provides a crippeled network
#     environment, sufficient enough for TCP to download
#     the portage tree and distfiles.
#   - No other special networking needs to be made. Qemu can be run
#     as a non-privilaged user.
#   - While the kernel is fairly standard
#     (sys-kernel/aufs-sources), however, network drivers and other
#     config is taylored for my environment.
#   - Kernel modules insude the initramfs are coupled to
#     the kernel version. (In theory, the initramfs could be
#     bundled into the kernel too)
#   - The initramfs is at least as big as any generated
#     tarball since the initramfs will effectively perform
#     a stage3 install during the boot process. It is a neat
#     chicken/egg problem that requires the stage3 to build the
#     initramfs, and the qemu/kernel/initramfs to (cleanly) build
#     the stage tarball.
#   - My custom dracut module is not documented (or described) here.

# Once the VM has booted, root login is permitted (without password)

# Set SYNC and GENTOO_MIRRORS variables in /etc/portage/make.conf first.
emerge --sync
eix-update

# Enable ssh, not sure why the ebuild didn't set these directories properly
chown root /var/empty
chmod 755 /var/empty
systemctl start sshd

# Run /usr/bin/passwd to set a password and enable remote logins
# (optional) passwd

# For some reason, binutils postinstall actions are not run properly.
# Manually make the symlinks, orphans will eventually be replaced
ln -sf /usr/x86_64-pc-linux-gnu/binutils-bin/2.23.2/* /usr/bin
emerge binutils
source /etc/profile

emerge -uDNvj dev-vcs/git world

git clone https://gist.github.com/6407310.git
(cd /; patch -p0 -l < /root/6407310/user.eclass.patch)

cd 6407310
bash stage-template.sh
bash build_stage3-systemd.sh
bash build_kernel.sh
bash prepare_dracut.sh
bash build_initrd.sh