# Copyright (C) 2009 Andy Spencer
# See COPYING for terms

# Config
MKSHELL=/usr/lib/plan9/bin/rc
NPROC=10

# Example
#test-start:VQPservice -u: foo-start
#	echo starting test
#	service -U $target
#
#test-stop:VQPservice -d: /
#	echo stopping test
#	service -D $target

# Runlevels
user   = alsa keymap polipo spam dbus
system = at cron hddtemp hostname hwclock sshd swap syslog
bare   = cpufreq fsclean getty qingy initctl localhost modules mounts uevents utmp

default:V: user

user:V:   `{echo $user^-start $system^-start $bare^-start}
system:V: `{echo $user^-stop  $system^-start $bare^-start}
bare:V:   `{echo $user^-stop  $system^-stop  $bare^-start}
single:V: `{echo $user^-stop  $system^-stop  $bare^-stop }

poweroff:V: halt 
	$P poweroff -ndf
reboot:V: halt
	$P reboot -ndf
kexec:V: halt
	$P reboot -ndfk

# Initial setup/shutdown for mkinit
boot:VEPservice -u: /
	echo Starting init
	$P mount -o remount,rw /
	# mount proc here to make bootchart happier
	$P mount -t proc proc /proc
	service -F
	service -U $target

# Kill all process, then remount and sync
halt:QVE: utmp-stop hwclock-stop alsa-stop
	echo TERMinating all processes
	$P pkill -15 -vg0 >/dev/null >[2=1]
	for (i in 1 2 3 4 5)
		$P pgrep -vg0 >/dev/null >[2=1] && $P sleep 1
	echo KILLing all processes
	$P pkill  -9 -vg0 >/dev/null >[2=1]
	for (i in 1 2 3)
		$P pgrep -vg0 >/dev/null >[2=1] && $P sleep 1
	service -F
	echo Remounting read-only
	$P mount -o remount,ro /
	$P sync

# Bare
# ----
# Listener for /dev/initctl, for shutdown(8)
initctl-start:VPservice -u: boot
	fifo=/dev/initctl
	if (! test -e $fifo)
		$P mkfifo $fifo
	{ exec $P initctld $fifo |
	  while(line=`{line})
		$P mkinit $line >/dev/console >[2=1] 
	} &
	service -U $target
initctl-stop_cmd=fuser -k /dev/initctl

# Proc, mtab, udev, fstab
mounts-start:VPservice -u: boot
	$P cp /proc/mounts /etc/mtab
	$P udevd --daemon
	$P mount -a
	service -U $target

# Load kernel modules
modules-start:VEPservice -u: boot
	$P modprobe uvesafb
	service -U $target

# Trigger udev uevents
uevents-start:VEPservice -u:  mounts-start
	$P udevadm trigger
	$P udevadm settle '--timeout=10'
	service -U $target

# Clean out /tmp and /var/run directories
fsclean-start:VPservice -u: boot
	dirs=(/var/run /tmp)
	$P mkdir -p /.old
	$P mv $dirs /.old
	$P mkdir -p $dirs
	$P chmod 1777 /tmp
	$P exec rm -rf /.old &
	service -U $target

# Spawn gettys for tty[456]
getty-start:VEPservice -u: hostname-start utmp-start
	$P respawn /sbin/agetty 38400 tty4 linux
	$P respawn /sbin/agetty 38400 tty5 linux
	$P respawn /sbin/agetty 38400 tty6 linux
	service -U $target
getty-stop_cmd=fuser -k /dev/tty4 /dev/tty5 /dev/tty6

# Spawn qingys for tty[23]
qingy-start:VEPservice -u: hostname-start utmp-start modules-start uevents-start
	$P respawn /sbin/qingy tty2
	$P respawn /sbin/qingy tty3
	service -U $target
qingy-stop_cmd=fuser -k /dev/tty2 /dev/tty3

# Login records
utmp-start:VPservice -u: fsclean-start
	for (i in /var/run/utmp /var/log/wtmp) {
		$P eval 'echo -n > $i'
		$P chgrp utmp $i
		$P chmod 0664 $i
	}
	service -U $target
utmp-stop_cmd=halt -w

# CPU freq
cpufreq-start:VPservice -u: uevents-start
	$P cpufreq-set -g ondemand
	service -U $target

# Keymap (us-cc = us with ctrl-capslock switched)
keymap-start_cmd=loadkeys -u us-cc

# Localhost
localhost-start_cmd=ifconfig lo 127.0.0.1
localhost-stop_cmd=ifconfig lo down

# Set hostname
hostname-start_cmd=hostname b

# Kernel parameters
sysctl-start_cmd=sysctl -p


# Console
# -------
at-start_cmd=atd
at-stop_cmd=pkill atd

cron-start_cmd=cron
cron-stop_cmd=pkill cron

hwclock-start_cmd=hwclock --hctosys --utc
hwclock-stop_cmd=hwclock --systohc --utc

swap-start_cmd=swapon -a
swap-stop_cmd=swapoff -a

syslog-start:VPservice -u: mounts-start
	$P syslog-ng
	service -U $target
syslog-stop_cmd=pkill syslog

hddtemp-start:VPservice -u: localhost-start
	$P hddtemp -d -l 127.0.0.1 /dev/sda
	service -U $target
hddtemp-stop_cmd=pkill hddtemp


# Desktop
# -------
alsa-start_cmd=alsactl restore
alsa-stop_cmd=alsactl store

sshd-start_cmd=/usr/sbin/sshd
sshd-stop_cmd=pkill sshd

dbus-start:VPservice -u: fsclean-start localhost-start
	$P mkdir -p /var/run/dbus
	$P /usr/bin/dbus-daemon --system
	service -U $target
dbus-stop_cmd=pkill dbus-daemon

spam-start:VPservice -u: localhost-start
	$P spamd -d
	service -U $target
spam-stop_cmd=pkill spamd

polipo-start:VPservice -u: localhost-start
	$P polipo
	service -U $target
polipo-stop_cmd=pkill polipo


# Library 
# -------
%-start:VPservice -u: boot
	if (~ $#($stem^-start_cmd) 0)
		exit 0
	$P $($stem^-start_cmd)
	service -U $target

%-stop:VPservice -d: /
	if (~ $#($stem^-stop_cmd) 0)
		exit 0
	$P $($stem^-stop_cmd)
	service -D $target

%-zap:VPservice -d: /
	service -D $target

%-status:V:
	service -q $target
