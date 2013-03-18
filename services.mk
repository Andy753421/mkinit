MKSHELL=/opt/plan9/bin/rc

# Example
#test-start:VQPservice -u: foo-start
#	echo starting test
#	service -U $target
#
#test-stop:VQPservice -d: /
#	echo stopping test
#	service -D $target

# Core commands
# -------------
# Reboot commands
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
	$P pkill -15 --inverse -g0 >/dev/null >[2=1]
	for (i in 1 2 3 4 5)
		{ $P pgrep -vg0 && $P sleep 1 }
	echo KILLing all processes
	$P pkill  -9 --inverse -g0 >/dev/null >[2=1]
	for (i in 1 2 3)
		{ $P pgrep -vg0 && $P sleep 1 }
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

# Proc, mtab, fstab
mounts-start:VPservice -u: boot
	$P cp /proc/mounts /etc/mtab
	$P mdadm -A /dev/md4 /dev/sd[abc]4
	$P mount -a
	service -U $target

# Mount devtmpfs and shm/pts subfolders
devtmpfs-start:VEPservice -u: boot
	$P mount /dev
	$P mkdir /dev/shm
	$P mkdir /dev/pts
	service -U $target

# Start mdev as initial/daemon
mdev-start:VEPservice -u: mounts-start
	$P echo /sbin/mdev > /proc/sys/kernel/hotplug
	$P mdev -s
	service -U $target

# Start udev and trigger events
udev-start:VEPservice -u:  mounts-start
	$P udevd --daemon
	$P udevadm trigger
	$P udevadm settle '--timeout=10'
	service -U $target
udev-stop_cmd=pkill udevd

# Load kernel modules
modules-start:VEPservice -u: boot
	$P modprobe uvesafb
	$P modprobe evdev
	service -U $target

# Clean out /tmp and /var/run directories
fsclean-start:VPservice -u: boot
	dirs=(/var/run /tmp)
	$P mkdir -p /.old
	$P mv $dirs /.old || true
	$P mkdir -p $dirs
	$P chmod 1777 /tmp
	$P install -m 1777 -d /var/run/screen # Fuck you Screen
	$P exec rm -rf /.old &
	service -U $target

# Spawn gettys for tty[23456]
getty-start:VEPservice -u: hostname-start utmp-start
	$P respawn setsid agetty 38400 tty2 linux
	$P respawn setsid agetty 38400 tty3 linux
	$P respawn setsid agetty 38400 tty4 linux
	$P respawn setsid agetty 38400 tty5 linux
	$P respawn setsid agetty 38400 tty6 linux
	service -U $target
getty-stop_cmd=fuser -k /dev/tty2 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6

# Spawn qingys for tty[7]
qingy-start:VEPservice -u: hostname-start utmp-start modules-start
	$P respawn setsid /sbin/qingy-DirectFB tty7 &
	$P chvt 7
	service -U $target
qingy-stop_cmd=fuser -k /dev/tty7

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
cpufreq-start:VPservice -u: mounts-start
	$P cpufreq-set -g ondemand
	service -U $target

# Localhost
localhost-start_cmd=ifconfig lo 127.0.0.1
localhost-stop_cmd=ifconfig lo down

# Set hostname
hostname-start_cmd=hostname

# Kernel parameters
sysctl-start:VPservice -u: mounts-start
	$P sysctl -p
	$P chmod a+w /sys/class/leds/smc::kbd_backlight/brightness
	$P chmod a+w /sys/class/backlight/gmux_backlight/brightness
	service -U $target


# System
# -------
at-start_cmd=atd
at-stop_cmd=pkill atd

cron-start_cmd=cron
cron-stop_cmd=pkill cron

hddtemp-start_cmd=hddtemp -d
hddtemp-stop_cmd=pkill hddtemp

hwclock-start_cmd=hwclock --hctosys --utc
hwclock-stop_cmd=hwclock --systohc --utc

sshd-start_cmd=/usr/sbin/sshd
sshd-stop_cmd=pkill sshd

swap-start_cmd=swapon -a
swap-stop_cmd=swapoff -a

syslog-start:VPservice -u: mounts-start
	$P syslog-ng
	service -U $target
syslog-stop_cmd=pkill syslog


# Desktop
# -------
alsa-start_cmd=alsactl restore
alsa-stop_cmd=alsactl store

cups-start_cmd=cupsd
cups-stop_cmd=pkill cupsd

dbus-start:VPservice -u: fsclean-start localhost-start
	$P install -m 1777 -d /var/run/dbus
	$P /usr/bin/dbus-daemon --system
	service -U $target
dbus-stop_cmd=pkill dbus-daemon

gpm-start_cmd=gpm -m /dev/input/mice -t ps2
gpm-stop_cmd=pkill gpm

gpsd-start_cmd=gpsd tcp://localhost:2222
gpsd-stop_cmd=pkill gpsd

keymap-start_cmd=loadkeys -u us-cc

polipo-start:VPservice -u: localhost-start
	$P polipo
	service -U $target
polipo-stop_cmd=pkill polipo


# Server
# ------
apache2-start:VPservice -u: fsclean-start
	$P install -o apache -g apache -d /var/run/session
	$P apache2 $apache2-opts
apache2-stop_cmd=pkill apache2

#bitlbee-start_cmd=sudo -u bitlbee bitlbeed /usr/sbin/bitlbee
bitlbee-start_cmd=bitlbee -D -u bitlbee
bitlbee-stop_cmd=pkill bitlbee

denyhosts-start_cmd=denyhosts.py --daemon
denyhosts-stop_cmd=pkill denyhosts.py

courier-start:VPservice -u: fsclean-start
	$P install -o mail -g mail -d /var/run/courier
	$P authdaemond       start
	$P courier           start
	$P courierfilter     start
	$P courier-imapd-ssl start
	service -U $target
courier-stop_cmd=pkill '(courier|authdaemon)'

dioc-start:VPservice -u: munged-start
	$P mount -n /mnt/c
	$P mount -n /mnt/c/mnt/x
	service -U $target
dioc-stop:EVPservice -d:
	$P umount /mnt/c/mnt/x
	$P umount /mnt/c
	service -D $target

diod-start:VPservice -u: munged-start
	$P diod --export-all
	service -U $target
diod-stop_cmd=pkill diod

dovecot-start_cmd=dovecot
dovecot-stop_cmd=pkill dovecot

eth0-start_cmd=dhcpcd eth0
eth0-stop_cmd=dhcpcd eth0 -k

exim-start_cmd=exim -bd -q5m
exim-stop_cmd=pkill exim

gitd-start:VPservice -u: boot
	$P exec /usr/libexec/git-core/git-daemon \
		'--syslog' \
		'--export-all' \
		'--user-path=git' \
		'--interpolated-path=/etc/git/%H%D' \
		'--listen=0.0.0.0' \
		'--user=nobody' \
		'--group=nobody' &
	service -U $target
gitd-stop_cmd=pkill git-daemon

mailman-start_cmd=sudo -u mailman -g mailman \
	/usr/lib64/mailman/bin/mailmanctl -s start
mailman-stop_cmd=sudo -u mailman -g mailman \
	/usr/lib64/mailman/bin/mailmanctl stop

munged-start:VPservice -u: boot
	$P install -o munge -g munge -d /var/run/munge
	$P sudo -u munge -g munge munged
	service -U $target
munged-stop_cmd=pkill munged

mysql-start:VPservice -u: fsclean-start
	$P install -o mysql -g mysql -d /var/run/mysqld
	$P exec mysqld &
	service -U $target
mysql-stop_cmd=pkill mysqld

ntpd-start_cmd=ntpd
ntpd-stop_cmd=pkill ntpd

privoxy-start_cmd=privoxy --user privoxy.privoxy /etc/privoxy/config
privoxy-stop_cmd=pkill privoxy

rngd-start_cmd=rngd -b -s64 -t60
rngd-stop_cmd=pkill rngd

spamd-start_cmd=spamd -u spamd -d
spamd-stop_cmd=pkill spamd

tftpd-start_cmd=in.tftpd -s -l /img/boot
tftpd-stop_cmd=

tor-start:VPservice -u: boot
	$P exec tor &
	service -U $target
tor-stop_cmd=pkill tor

wlan0-start:VPservice -u: wpa-start
	$P dhcpcd wlan0
	service -U $target
wlan0-stop_cmd=dhcpcd wlan0 -k

wpa-start:VPservice -u: mdev-start
	$P modprobe b43
	$P exec wpa_supplicant -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf &
	service -U $target
wpa-stop_cmd=pkill wpa

# Library 
# -------
%-start:QVPservice -u: boot
	if (~ $#($stem^-start_cmd) 0)
		echo No such service $stem && exit 0
	$P $($stem^-start_cmd) $($stem^-opts)
	service -U $target

%-stop:QVPservice -d: /
	if (~ $#($stem^-stop_cmd) 0)
		echo No such service $stem
	if not
		$P $($stem^-stop_cmd)
	service -D $target

%-zap:QVPservice -d: /
	service -D $target

%-status:QV:
	service -q $target
