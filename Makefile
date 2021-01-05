PN = monitorix

PREFIX ?= /usr
CONFDIR = /etc
BASEDIR = /var/lib/monitorix
WWWDIR = $(BASEDIR)/www
DBDIR = /var/lib/monitorix
LIBDIR = /usr/lib/monitorix
INITDIR_SYSTEMD = $(PREFIX)/lib/systemd/system
INITDIR_RHEL = $(CONFDIR)/rc.d/init.d
INITDIR_OTHER = $(CONFDIR)/init.d
BINDIR = $(PREFIX)/bin
DOCDIR = $(PREFIX)/share/doc/$(PN)
MAN5DIR = $(PREFIX)/share/man/man5
MAN8DIR = $(PREFIX)/share/man/man8

RM = rm -f
RMD = rmdir
SED = sed
INSTALL = install -p
INSTALL_PROGRAM = $(INSTALL) -m755
INSTALL_DATA = $(INSTALL) -m644
INSTALL_DIR = $(INSTALL) -d
INSTALL_WORLDDIR = $(INSTALL) -dm755

Q = @

help: install

install:
	$(Q)echo "Run one of the following:"
	$(Q)echo "  make install-systemd-all (systemd based systems)"
	$(Q)echo "  make install-upstart-all (upstart based systems)"
	$(Q)echo "  make install-debian-all (legacy debian sysv based systems)"
	$(Q)echo "  make install-redhat-all (legacy redhat sysv based systems)"
	$(Q)echo
	$(Q)echo "Default targets may be overridden on the shell so"
	$(Q)echo "check out the Makefile for specific rules."

install-bin:
	$(Q)echo -e '\033[1;32mInstalling script and modules...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(BINDIR)"
	$(INSTALL_PROGRAM) $(PN) "$(DESTDIR)$(BINDIR)/$(PN)"
	
	$(INSTALL_DIR) "$(DESTDIR)$(DBDIR)"
	
	$(INSTALL_DIR) "$(DESTDIR)$(BASEDIR)"
	$(INSTALL_DIR) "$(DESTDIR)$(WWWDIR)"
	$(INSTALL_DIR) "$(DESTDIR)$(WWWDIR)/cgi"
	$(INSTALL_WORLDDIR) "$(DESTDIR)$(WWWDIR)/imgs"
	$(INSTALL_PROGRAM) $(PN).cgi "$(DESTDIR)$(WWWDIR)/cgi/$(PN).cgi"
	$(INSTALL_DATA) logo_bot.png "$(DESTDIR)$(WWWDIR)/logo_bot.png"
	$(INSTALL_DATA) logo_top.png "$(DESTDIR)$(WWWDIR)/logo_top.png"
	$(INSTALL_DATA) monitorixico.png "$(DESTDIR)$(WWWDIR)/monitorixico.png"

	$(INSTALL_DIR) "$(DESTDIR)$(WWWDIR)/css"
	$(INSTALL_DATA) css/black.css "$(DESTDIR)$(WWWDIR)/css/black.css"
	$(INSTALL_DATA) css/white.css "$(DESTDIR)$(WWWDIR)/css/white.css"

	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)/$(PN)"
	$(INSTALL_DATA) $(PN).conf "$(DESTDIR)$(CONFDIR)/$(PN)/$(PN).conf"
	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)/$(PN)/conf.d"

	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)/logrotate.d/"
	$(INSTALL_DATA) docs/$(PN).logrotate "$(DESTDIR)$(CONFDIR)/logrotate.d/$(PN)"
	
	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)/sysconfig"
	$(INSTALL_DATA) docs/$(PN).sysconfig "$(DESTDIR)$(CONFDIR)/sysconfig/$(PN)"
	
	$(INSTALL_DIR) "$(DESTDIR)$(LIBDIR)"
	$(INSTALL_DATA) lib/ambsens.pm "$(DESTDIR)$(LIBDIR)/ambsens.pm"
	$(INSTALL_DATA) lib/apache.pm "$(DESTDIR)$(LIBDIR)/apache.pm"
	$(INSTALL_DATA) lib/apcupsd.pm "$(DESTDIR)$(LIBDIR)/apcupsd.pm"
	$(INSTALL_DATA) lib/bind.pm "$(DESTDIR)$(LIBDIR)/bind.pm"
	$(INSTALL_DATA) lib/chrony.pm "$(DESTDIR)$(LIBDIR)/chrony.pm"
	$(INSTALL_DATA) lib/disk.pm "$(DESTDIR)$(LIBDIR)/disk.pm"
	$(INSTALL_DATA) lib/du.pm "$(DESTDIR)$(LIBDIR)/du.pm"
	$(INSTALL_DATA) lib/emailreports.pm "$(DESTDIR)$(LIBDIR)/emailreports.pm"
	$(INSTALL_DATA) lib/fail2ban.pm "$(DESTDIR)$(LIBDIR)/fail2ban.pm"
	$(INSTALL_DATA) lib/fs.pm "$(DESTDIR)$(LIBDIR)/fs.pm"
	$(INSTALL_DATA) lib/ftp.pm "$(DESTDIR)$(LIBDIR)/ftp.pm"
	$(INSTALL_DATA) lib/gensens.pm "$(DESTDIR)$(LIBDIR)/gensens.pm"
	$(INSTALL_DATA) lib/hptemp.pm "$(DESTDIR)$(LIBDIR)/hptemp.pm"
	$(INSTALL_DATA) lib/HTTPServer.pm "$(DESTDIR)$(LIBDIR)/HTTPServer.pm"
	$(INSTALL_DATA) lib/icecast.pm "$(DESTDIR)$(LIBDIR)/icecast.pm"
	$(INSTALL_DATA) lib/int.pm "$(DESTDIR)$(LIBDIR)/int.pm"
	$(INSTALL_DATA) lib/ipmi.pm "$(DESTDIR)$(LIBDIR)/ipmi.pm"
	$(INSTALL_DATA) lib/kern.pm "$(DESTDIR)$(LIBDIR)/kern.pm"
	$(INSTALL_DATA) lib/libvirt.pm "$(DESTDIR)$(LIBDIR)/libvirt.pm"
	$(INSTALL_DATA) lib/lighttpd.pm "$(DESTDIR)$(LIBDIR)/lighttpd.pm"
	$(INSTALL_DATA) lib/lmsens.pm "$(DESTDIR)$(LIBDIR)/lmsens.pm"
	$(INSTALL_DATA) lib/mail.pm "$(DESTDIR)$(LIBDIR)/mail.pm"
	$(INSTALL_DATA) lib/memcached.pm "$(DESTDIR)$(LIBDIR)/memcached.pm"
	$(INSTALL_DATA) lib/mongodb.pm "$(DESTDIR)$(LIBDIR)/mongodb.pm"
	$(INSTALL_DATA) lib/Monitorix.pm "$(DESTDIR)$(LIBDIR)/Monitorix.pm"
	$(INSTALL_DATA) lib/mysql.pm "$(DESTDIR)$(LIBDIR)/mysql.pm"
	$(INSTALL_DATA) lib/net.pm "$(DESTDIR)$(LIBDIR)/net.pm"
	$(INSTALL_DATA) lib/netstat.pm "$(DESTDIR)$(LIBDIR)/netstat.pm"
	$(INSTALL_DATA) lib/nfsc.pm "$(DESTDIR)$(LIBDIR)/nfsc.pm"
	$(INSTALL_DATA) lib/nfss.pm "$(DESTDIR)$(LIBDIR)/nfss.pm"
	$(INSTALL_DATA) lib/nginx.pm "$(DESTDIR)$(LIBDIR)/nginx.pm"
	$(INSTALL_DATA) lib/ntp.pm "$(DESTDIR)$(LIBDIR)/ntp.pm"
	$(INSTALL_DATA) lib/nut.pm "$(DESTDIR)$(LIBDIR)/nut.pm"
	$(INSTALL_DATA) lib/nvidia.pm "$(DESTDIR)$(LIBDIR)/nvidia.pm"
	$(INSTALL_DATA) lib/pagespeed.pm "$(DESTDIR)$(LIBDIR)/pagespeed.pm"
	$(INSTALL_DATA) lib/pgsql.pm "$(DESTDIR)$(LIBDIR)/pgsql.pm"
	$(INSTALL_DATA) lib/phpapc.pm "$(DESTDIR)$(LIBDIR)/phpapc.pm"
	$(INSTALL_DATA) lib/phpfpm.pm "$(DESTDIR)$(LIBDIR)/phpfpm.pm"
	$(INSTALL_DATA) lib/port.pm "$(DESTDIR)$(LIBDIR)/port.pm"
	$(INSTALL_DATA) lib/process.pm "$(DESTDIR)$(LIBDIR)/process.pm"
	$(INSTALL_DATA) lib/proc.pm "$(DESTDIR)$(LIBDIR)/proc.pm"
	$(INSTALL_DATA) lib/raspberrypi.pm "$(DESTDIR)$(LIBDIR)/raspberrypi.pm"
	$(INSTALL_DATA) lib/redis.pm "$(DESTDIR)$(LIBDIR)/redis.pm"
	$(INSTALL_DATA) lib/serv.pm "$(DESTDIR)$(LIBDIR)/serv.pm"
	$(INSTALL_DATA) lib/squid.pm "$(DESTDIR)$(LIBDIR)/squid.pm"
	$(INSTALL_DATA) lib/system.pm "$(DESTDIR)$(LIBDIR)/system.pm"
	$(INSTALL_DATA) lib/tc.pm "$(DESTDIR)$(LIBDIR)/tc.pm"
	$(INSTALL_DATA) lib/tinyproxy.pm "$(DESTDIR)$(LIBDIR)/tinyproxy.pm"
	$(INSTALL_DATA) lib/traffacct.pm "$(DESTDIR)$(LIBDIR)/traffacct.pm"
	$(INSTALL_DATA) lib/unbound.pm "$(DESTDIR)$(LIBDIR)/unbound.pm"
	$(INSTALL_DATA) lib/user.pm "$(DESTDIR)$(LIBDIR)/user.pm"
	$(INSTALL_DATA) lib/varnish.pm "$(DESTDIR)$(LIBDIR)/varnish.pm"
	$(INSTALL_DATA) lib/verlihub.pm "$(DESTDIR)$(LIBDIR)/verlihub.pm"
	$(INSTALL_DATA) lib/wowza.pm "$(DESTDIR)$(LIBDIR)/wowza.pm"
	$(INSTALL_DATA) lib/zfs.pm "$(DESTDIR)$(LIBDIR)/zfs.pm"

	$(INSTALL_DIR) "$(DESTDIR)$(BASEDIR)/reports"
	$(INSTALL_DATA) reports/ca.html "$(DESTDIR)$(BASEDIR)/reports/ca.html"
	$(INSTALL_DATA) reports/de.html "$(DESTDIR)$(BASEDIR)/reports/de.html"
	$(INSTALL_DATA) reports/en.html "$(DESTDIR)$(BASEDIR)/reports/en.html"
	$(INSTALL_DATA) reports/it.html "$(DESTDIR)$(BASEDIR)/reports/it.html"
	$(INSTALL_DATA) reports/nl_NL.html "$(DESTDIR)$(BASEDIR)/reports/nl_NL.html"
	$(INSTALL_DATA) reports/pl.html "$(DESTDIR)$(BASEDIR)/reports/pl.html"
	$(INSTALL_DATA) reports/zh_CN.html "$(DESTDIR)$(BASEDIR)/reports/zh_CN.html"

	$(INSTALL_DIR) "$(DESTDIR)$(BASEDIR)/usage"

install-docs:
	$(Q)echo -e '\033[1;32mInstalling docs...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(DOCDIR)"
	$(INSTALL_PROGRAM) docs/$(PN)-alert.sh "$(DESTDIR)$(DOCDIR)/$(PN)-alert.sh"
	$(INSTALL_PROGRAM) docs/htpasswd.pl "$(DESTDIR)$(DOCDIR)/htpasswd.pl"
	$(INSTALL_DATA) Changes "$(DESTDIR)$(DOCDIR)/Changes"
	$(INSTALL_DATA) COPYING "$(DESTDIR)$(DOCDIR)/COPYING"
	$(INSTALL_DATA) README "$(DESTDIR)$(DOCDIR)/README"
	$(INSTALL_DATA) README.BSD "$(DESTDIR)$(DOCDIR)/README.BSD"
	$(INSTALL_DATA) README.nginx "$(DESTDIR)$(DOCDIR)/README.nginx"
	$(INSTALL_DATA) docs/$(PN)-lighttpd.conf "$(DESTDIR)$(DOCDIR)/$(PN)-lighttpd.conf"
	$(INSTALL_DATA) docs/$(PN)-apache.conf "$(DESTDIR)$(DOCDIR)/$(PN)-apache.conf"

install-man:
	$(Q)echo -e '\033[1;32mInstalling manpages...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(MAN5DIR)"
	$(INSTALL_DATA) man/man5/$(PN).conf.5 "$(DESTDIR)$(MAN5DIR)/$(PN).conf.5"

	$(INSTALL_DIR) "$(DESTDIR)$(MAN8DIR)"
	gzip -9 "$(DESTDIR)$(MAN5DIR)/$(PN).conf.5"
	$(INSTALL_DATA) man/man8/$(PN).8 "$(DESTDIR)$(MAN8DIR)/$(PN).8"
	gzip -9 "$(DESTDIR)$(MAN8DIR)/$(PN).8"

install-systemd:
	$(Q)echo -e '\033[1;32mInstalling systemd service...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)"
	$(INSTALL_DIR) "$(DESTDIR)$(INITDIR_SYSTEMD)"
	$(INSTALL_DATA) docs/$(PN).service "$(DESTDIR)$(INITDIR_SYSTEMD)/$(PN).service"

install-upstart:
	$(Q)echo -e '\033[1;32mInstalling upstart service...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(INITDIR_OTHER)"
	$(INSTALL_PROGRAM) docs/$(PN).upstart "$(DESTDIR)$(INITDIR_OTHER)/$(PN)"

install-debian:
	$(Q)echo -e '\033[1;32mInstalling debian sysv service...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(INITDIR_OTHER)"
	$(INSTALL_PROGRAM) docs/$(PN)-deb.init "$(DESTDIR)$(INITDIR_OTHER)/$(PN)"
	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)/$(PN)/conf.d"
	$(INSTALL_DATA) docs/debian.conf "$(DESTDIR)$(CONFDIR)/$(PN)/conf.d/00-debian.conf"

install-redhat:
	$(Q)echo -e '\033[1;32mInstalling redhat sysv service...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(INITDIR_RHEL)"
	$(INSTALL_PROGRAM) docs/$(PN).init "$(DESTDIR)$(INITDIR_RHEL)/$(PN)"

install-systemd-all: install-bin install-man install-docs install-systemd

install-upstart-all: install-bin install-man install-docs install-upstart

install-debian-all: install-bin install-man install-docs install-debian

install-redhat-all: install-bin install-man install-docs install-redhat

uninstall-bin:
	$(RM) "$(DESTDIR)$(BINDIR)/$(PN)"
	$(RM) "$(DESTDIR)$(WWWDIR)/cgi/$(PN).cgi"
	$(RM) "$(DESTDIR)$(WWWDIR)/logo_bot.png"
	$(RM) "$(DESTDIR)$(WWWDIR)/logo_top.png"
	$(RM) "$(DESTDIR)$(WWWDIR)/monitorixico.png"
	$(RM) "$(DESTDIR)$(CONFDIR)/$(PN)/$(PN).conf"
	$(RM) "$(DESTDIR)$(CONFDIR)/logrotate.d/$(PN)"
	$(RM) "$(DESTDIR)$(CONFDIR)/sysconfig/$(PN)"
	$(RM) "$(DESTDIR)$(LIBDIR)/"*.pm
	$(RM) "$(DESTDIR)$(BASEDIR)/reports/"*.html
	$(RMD) "$(DESTDIR)$(LIBDIR)/"
	$(RMD) "$(DESTDIR)$(WWWDIR)/cgi"

uninstall-docs:
	$(RM) "$(DESTDIR)$(DOCDIR)/$(PN)-alert.sh"
	$(RM) "$(DESTDIR)$(DOCDIR)/htpasswd.pl"
	$(RM) "$(DESTDIR)$(DOCDIR)/COPYING"
	$(RM) "$(DESTDIR)$(DOCDIR)/Changes"
	$(RM) "$(DESTDIR)$(DOCDIR)/"README*
	$(RM) "$(DESTDIR)$(DOCDIR)/"*.conf

uninstall-man:
	$(RM) "$(DESTDIR)$(MAN5DIR)/$(PN).conf.5.gz"
	$(RM) "$(DESTDIR)$(MAN8DIR)/$(PN).8.gz"

uninstall-systemd:
	$(RM) "$(DESTDIR)$(INITDIR_SYSTEMD)/$(PN).service"

uninstall-upstart:
	$(RM) "$(DESTDIR)$(INITDIR_OTHER)/$(PN)"

uninstall-debian:
	$(RM) "$(DESTDIR)$(INITDIR_OTHER)/$(PN)"
	$(RM) "$(DESTDIR)$(CONFDIR)/$(PN)/conf.d/00-debian.conf"

uninstall-redhat:
	$(RM) "$(DESTDIR)$(INITDIR_RHEL)/$(PN)"

uninstall-systemd-all: uninstall-bin uninstall-man uninstall-docs uninstall-systemd

uninstall-upstart-all: uninstall-bin uninstall-man uninstall-docs uninstall-upstart

uninstall-debian-all: uninstall-bin uninstall-man uninstall-docs uninstall-debian

uninstall-redhat-all: uninstall-bin uninstall-man uninstall-docs uninstall-redhat

uninstall:
	$(Q)echo "run one of the following:"
	$(Q)echo "  make uninstall-systemd-all (systemd based systems)"
	$(Q)echo "  make uninstall-upstart-all (upstart based systems)"
	$(Q)echo "  make uninstall-debian-all (debian sysv based systems)"
	$(Q)echo "  make uninstall-redhat-all (redhat sysv based systems)"
	$(Q)echo
	$(Q)echo "or check out the Makefile for specific rules"

.PHONY: help install-bin install-docs install-man install-systemd install-upstart install-debian install-redhat install-systemd-all install-upstart-all install-debian-all install-redhat-all install uninstall-bin uninstall-docs uninstall-man uninstall-systemd uninstall-upstart uninstall-debian uinstall-redhat uninstall-systemd-all uninstall-upstart-all uninstall-debian-all uninstall-redhat-all uninstall
