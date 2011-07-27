# Copyright (C) 2009-2011 Andy Spencer
# See COPYING for terms

# Config
MKSHELL=/opt/plan9/bin/rc
NPROC=10

hostname-opts = c
apache2-opts  = -DSSL -DPHP5

# Runlevels:
#   single─bare─system─┬─desktop─>
#                      └─server──>
server  = apache2 bitlbee dhcp dovecot exim gitd mysql ntpd spamd
desktop = alsa cups dbus getty qingy keymap polipo
system  = at cron hddtemp hwclock mdev sshd swap syslog
bare    = cpufreq fsclean hostname initctl localhost modules mounts uevents utmp

default:V: desktop

server:V:  `{echo $server^-start                 $system^-start $bare^-start}
desktop:V: `{echo                $desktop^-start $system^-start $bare^-start}
system:V:  `{echo $server^-stop  $desktop^-stop  $system^-start $bare^-start}
bare:V:    `{echo $server^-stop  $desktop^-stop  $system^-stop  $bare^-start}
single:V:  `{echo $server^-stop  $desktop^-stop  $system^-stop  $bare^-stop }

# Include services
</scratch/lug/mkinit/init.mk
