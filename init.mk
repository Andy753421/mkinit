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
system = at cron hddtemp hostname hwclock i8k sshd swap syslog
bare   = cpufreq fsclean getty qingy localhost modules mounts uevents utmp

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
boot:QVEPservice -u: /
	echo Starting init
	$P mount -o remount,rw /
	# mount proc here to make bootchart happier
	$P mount -t proc proc /proc
	rm -f /lib/mkinit/state/*
	service -U $target

# Kill all process, then remount and sync
halt:QVE: utmp-stop hwclock-stop alsa-stop
	echo Stopping init
	rm -f /lib/mkinit/state/*
	
	echo TERMinating all processes
	$P pkill -15 -vg0
	for (i in 1 2 3 4 5)
		$P pgrep -vg0 >/dev/null && $P sleep 1
	
	echo KILLing all processes
	$P pkill  -9 -vg0
	for (i in 1 2 3)
		$P pgrep -vg0 >/dev/null && $P sleep 1
	
	$P mount -o remount,ro /
	$P sync

# Bare
# ----
# Proc, mtab, udev, fstab
mounts-start:QVPservice -u: boot
	echo Starting mounts
	$P cat /proc/mounts > /etc/mtab
	$P udevd --daemon
	$P mount -a 
	service -U $target

# Load kernel modules
modules-start:QVEPservice -u: boot
	echo Starting modules
	$P modprobe uvesafb
	service -U $target

# Trigger udev uevents
uevents-start:QVEPservice -u:  mounts-start
	echo Starting uevents
	$P udevadm trigger
	$P udevadm settle '--timeout=10'
	service -U $target

# Clean out /tmp and /var/run directories
fsclean-start:QVPservice -u: boot
	echo Starting fsclean
	$P rm -rf /tmp/* 
	$P rm -rf /var/run/*
	service -U $target

# Spawn gettys for tty[456]
getty-start:QVPservice -u: hostname-start utmp-start
	echo Starting getty
	$P respawn /sbin/agetty 38400 tty4 linux &
	$P respawn /sbin/agetty 38400 tty5 linux &
	$P respawn /sbin/agetty 38400 tty6 linux &
	service -U $target
getty-stop_cmd=pkill agetty

# Spawn qingys for tty[23]
qingy-start:QVPservice -u: hostname-start utmp-start modules-start uevents-start
	echo Starting qingy
	$P respawn /sbin/qingy tty2 &
	$P respawn /sbin/qingy tty3 &
	service -U $target
getty-stop_cmd=pkill qingy

# Login records
utmp-start:QVPservice -u: fsclean-start
	echo Starting utmp
	for (i in /var/run/utmp /var/log/wtmp) {
		echo -n > $i
		chgrp utmp $i
		chmod 0664 $i
	}
	service -U $target
utmp-stop_cmd=halt -w

# CPU freq
cpufreq-start:QVPservice -u: uevents-start
	echo Starting cpufreq
	cpufreq-set -g ondemand
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

syslog-start:QVPservice -u: mounts-start
	echo Starting syslog;
	$P syslog-ng
	service -U $target
syslog-stop_cmd=pkill syslog

hddtemp-start:QVPservice -u: localhost-start
	echo Starting hddtemp
	$P hddtemp -d -l 127.0.0.1 /dev/sda
	service -U $target
hddtemp-stop_cmd=pkill hddtemp


# Desktop
# -------
alsa-start_cmd=alsactl restore
alsa-stop_cmd=alsactl store

sshd-start_cmd=/usr/sbin/sshd
sshd-stop_cmd=pkill sshd

dbus-start:QVPservice -u: fsclean-start localhost-start
	echo Starting dbus
	$P mkdir -p /var/run/dbus
	$P /usr/bin/dbus-daemon --system
	service -U $target
dbus-stop_cmd=pkill dbus-daemon

spam-start:QVPservice -u: localhost-start
	echo Starting spam
	$P spamd -d
	service -U $target
spam-stop_cmd=pkill spamd

polipo-start:QVPservice -u: localhost-start
	echo Starting poliop
	$P polipo
	service -U $target
polipo-stop_cmd=pkill polipo


# Library 
# -------
%-start:QVPservice -u: boot
	if (~ $#($stem^-start_cmd) 0)
		exit 0
	echo Starting $stem
	$P $($stem^-start_cmd)
	service -U $target

%-stop:QVPservice -d: /
	if (~ $#($stem^-stop_cmd) 0)
		exit 0
	echo Stopping $stem
	$P $($stem^-stop_cmd)
	service -D $target

%-zap:QVPservice -d: /
	service -D $target

%-status:QV:
	service -q $target
