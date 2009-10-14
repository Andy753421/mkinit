# Copyright (C) 2009 Andy Spencer
# See COPYING for terms

# Config
PATH=/lib/mkinit/bin:/bin:/sbin:/usr/bin:/usr/sbin
MKSHELL=/usr/lib/plan9/bin/rc
NPROC=10

# Example
#start-test:VQPservice -u: start-foo
#	echo starting test
#	service -U $target
#
#stop-test:VQPservice -d: /
#	echo stopping test
#	service -D $target

# Runlevels
# Make getty wait (for bootchart)
default:V: user

user:V:   system `{echo start-^(alsa keymap polipo spam)}
system:V: bare   `{echo start-^(at cron hddtemp hostname hwclock i8k sshd swap syslog)}
bare:V:          `{echo start-^(cpufreq fsclean getty localhost modules mounts uevents)}

# Initial setup/shutdown for mkinit
boot:QVEPservice -u: /
	echo Starting init
	$P mount -o remount,rw /
	# mount proc here to make bootchart happier
	$P mount -t proc proc /proc
	rm -f /lib/mkinit/state/*
	service -U $target

# Kill all process, then remount and sync
halt:QVE: stop-utmp stop-hwclock stop-alsa
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

# Proc, mtab, udev, fstab
start-mounts:QVPservice -u: boot
	echo Starting mounts
	$P cat /proc/mounts > /etc/mtab
	$P udevd --daemon
	$P mount -a 
	service -U $target

# Load kernel modules
start-modules:QVEPservice -u: boot
	echo Starting modules
	$P modprobe uvesafb
	service -U $target

# Trigger udev uevents
start-uevents:QVEPservice -u:  start-mounts
	echo Starting uevents
	$P udevadm trigger
	$P udevadm settle '--timeout=10'
	service -U $target

# Clean out /tmp and /var/run directories
start-fsclean:QVPservice -u: boot
	echo Starting fsclean
	$P rm -rf /tmp/* 
	$P rm -rf /var/run/*
	service -U $target

# Spawn gettys for tty[456]
start-getty:QVPservice -u: start-hostname start-utmp
	echo Starting getty
	$P respawn /sbin/agetty 38400 tty4 linux &
	$P respawn /sbin/agetty 38400 tty5 linux &
	$P respawn /sbin/agetty 38400 tty6 linux &
	service -U $target

# Spawn qingys for tty[23]
start-qingy:QVPservice -u: start-hostname start-utmp start-modules start-uevents
	echo Starting qingy
	$P respawn /sbin/qingy tty2 &
	$P respawn /sbin/qingy tty3 &
	service -U $target

# Login records
start-utmp:QVPservice -u: start-fsclean
	echo Starting utmp
	for (i in /var/run/utmp /var/log/wtmp) {
		echo -n > $i
		chgrp utmp $i
		chmod 0664 $i
	}
	service -U $target
utmp_stop_cmd=halt -w

# CPU freq
start-cpufreq:QVPservice -u: start-uevents
	echo Starting cpufreq
	cpufreq-set -g ondemand
	service -U $target

# Keymap (us-cc = us with ctrl-capslock switched)
keymap_start_cmd=loadkeys -u us-cc

# Localhost
localhost_start_cmd=ifconfig lo 127.0.0.1
localhost_stop_cmd=ifconfig lo down

# Set hostname
hostname_start_cmd=hostname b

# Kernel parameters
sysctl_start_cmd=sysctl -p


# Console
# -------
at_start_cmd=atd
cron_start_cmd=cron
hwclock_start_cmd=hwclock --hctosys --utc
hwclock_stop_cmd=hwclock --systohc --utc
swap_start_cmd=swapon -a
swap_stop_cmd=swapoff -a
start-syslog:QVPservice -u: start-mounts
	echo Starting syslog;
	$P syslog-ng
	service -U $target
start-hddtemp:QVPservice -u: start-localhost
	echo Starting hddtemp
	$P hddtemp -d -l 127.0.0.1 /dev/sda
	service -U $target
hddtemp_stop_cmd=pkill hddtemp


# Desktop
# -------
alsa_start_cmd=alsactl restore
alsa_stop_cmd=alsactl store
sshd_start_cmd=/usr/sbin/sshd
start-spam:QVPservice -u: start-localhost
	echo Starting spam
	$P spamd -d
	service -U $target
start-polipo:QVPservice -u: start-localhost
	echo Starting poliop
	$P polipo
	service -U $target
polipo_stop_cmd=pkill polipo


# Library 
# -------
start-%:QVPservice -u: boot
	if (~ $#($stem^_start_cmd) 0)
		exit 0
	echo Starting $stem
	$P $($stem^_start_cmd)
	service -U $target

stop-%:QVPservice -d: /
	if (~ $#($stem^_stop_cmd) 0)
		exit 0
	echo Stopping $stem
	$P $($stem^_stop_cmd)
	service -D $target

zap-%:QVPservice -d: /
	service -D $target

status-%:QV:
	service -q $target
