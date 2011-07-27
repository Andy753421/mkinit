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
desktop = alsa dbus getty gpm keymap qingy
system  = at cron hddtemp hwclock sshd swap syslog
bare    = cpufreq fsclean hostname initctl localhost mdev modules mounts utmp

default:V: desktop

server:V:  `{echo $server^-start                 $system^-start $bare^-start}
desktop:V: `{echo                $desktop^-start $system^-start $bare^-start}
system:V:  `{echo $server^-stop  $desktop^-stop  $system^-start $bare^-start}
bare:V:    `{echo $server^-stop  $desktop^-stop  $system^-stop  $bare^-start}
single:V:  `{echo $server^-stop  $desktop^-stop  $system^-stop  $bare^-stop }

# Include services
</scratch/lug/mkinit/services.mk
