VERSION = 3.5.2
RELEASEDATE = 20-Aug-2014
PN = monitorix

PREFIX ?= /usr
CONFDIR = /etc
BASEDIR = /var/lib/monitorix/www
LIBDIR = /var/lib/monitorix
INITDIR_SYSTEMD = $(PREFIX)/lib/systemd/system
INITDIR_UPSTART = $(PREFIX)/init.d
BINDIR = $(PREFIX)/bin
DOCDIR = $(PREFIX)/share/doc/$(PN)
MAN5DIR = $(PREFIX)/share/man/man5
MAN8DIR = $(PREFIX)/share/man/man8

RM = rm -f
RMD = rmdir
SED = sed
INSTALL = install -p
INSTALL_PROGRAM = $(INSTALL) -m755
INSTALL_SCRIPT = $(INSTALL) -m755
INSTALL_DATA = $(INSTALL) -m644
INSTALL_DIR = $(INSTALL) -d

Q = @

$(PN): $(PN).in
	$(Q)echo -e '\033[1;32mSetting version info\033[0m'
	$(Q)$(SED) -e 's/@VERSION@/'$(VERSION)'/' $(PN).in \
		-e 's/@RELEASEDATE@/'$(RELEASEDATE)'/' > $(PN)

help: install

install:
	$(Q)echo "Run one of the following:"
	$(Q)echo "  make install-systemd-all (systemd based systems)"
	$(Q)echo "  make install-upstart-all (upstart based systems)"
	$(Q)echo
	$(Q)echo "Default targets may be overridden on the shell so"
	$(Q)echo "check out the Makefile for specific rules."

install-bin:
	$(Q)echo -e '\033[1;32mInstalling script and modules...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(BINDIR)"
	$(INSTALL_PROGRAM) $(PN) "$(DESTDIR)$(BINDIR)/$(PN)"
	
	$(INSTALL_DIR) "$(DESTDIR)$(BASEDIR)/cgi"
	$(INSTALL_DIR) "$(DESTDIR)$(BASEDIR)/imgs"
	$(INSTALL_PROGRAM) $(PN).cgi "$(DESTDIR)$(BASEDIR)/cgi/$(PN).cgi"
	$(INSTALL_DATA) logo_bot.png "$(DESTDIR)$(BASEDIR)/logo_bot.png"
	$(INSTALL_DATA) logo_top.png "$(DESTDIR)$(BASEDIR)/logo_top.png"
	$(INSTALL_DATA) monitorixico.png "$(DESTDIR)$(BASEDIR)/monitorixico.png"

	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)/$(PN)"
	$(INSTALL_DATA) $(PN).conf "$(DESTDIR)$(CONFDIR)/$(PN)/$(PN).conf"

	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)/logrotate.d/"
	$(INSTALL_DATA) docs/$(PN).logrotate "$(DESTDIR)$(CONFDIR)/logrotate.d/$(PN).logrotate"
	
	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)/sysconfig"
	$(INSTALL_DATA) docs/$(PN).sysconfig "$(DESTDIR)$(CONFDIR)/sysconfig//$(PN).sysconfig"
	
	$(INSTALL_DIR) "$(DESTDIR)$(LIBDIR)"
	$(INSTALL_DATA) lib/apache.pm "$(DESTDIR)$(LIBDIR)/apache.pm"
	$(INSTALL_DATA) lib/apcupsd.pm "$(DESTDIR)$(LIBDIR)/apcupsd.pm"
	$(INSTALL_DATA) lib/bind.pm "$(DESTDIR)$(LIBDIR)/bind.pm"
	$(INSTALL_DATA) lib/disk.pm "$(DESTDIR)$(LIBDIR)/disk.pm"
	$(INSTALL_DATA) lib/emailreports.pm "$(DESTDIR)$(LIBDIR)/emailreports.pm"
	$(INSTALL_DATA) lib/fail2ban.pm "$(DESTDIR)$(LIBDIR)/fail2ban.pm"
	$(INSTALL_DATA) lib/fs.pm "$(DESTDIR)$(LIBDIR)/fs.pm"
	$(INSTALL_DATA) lib/ftp.pm "$(DESTDIR)$(LIBDIR)/ftp.pm"
	$(INSTALL_DATA) lib/hptemp.pm "$(DESTDIR)$(LIBDIR)/hptemp.pm"
	$(INSTALL_DATA) lib/HTTPServer.pm "$(DESTDIR)$(LIBDIR)/HTTPServer.pm"
	$(INSTALL_DATA) lib/icecast.pm "$(DESTDIR)$(LIBDIR)/icecast.pm"
	$(INSTALL_DATA) lib/int.pm "$(DESTDIR)$(LIBDIR)/int.pm"
	$(INSTALL_DATA) lib/kern.pm "$(DESTDIR)$(LIBDIR)/kern.pm"
	$(INSTALL_DATA) lib/libvirt.pm "$(DESTDIR)$(LIBDIR)/libvirt.pm"
	$(INSTALL_DATA) lib/lighttpd.pm "$(DESTDIR)$(LIBDIR)/lighttpd.pm"
	$(INSTALL_DATA) lib/lmsens.pm "$(DESTDIR)$(LIBDIR)/lmsens.pm"
	$(INSTALL_DATA) lib/mail.pm "$(DESTDIR)$(LIBDIR)/mail.pm"
	$(INSTALL_DATA) lib/memcached.pm "$(DESTDIR)$(LIBDIR)/memcached.pm"
	$(INSTALL_DATA) lib/Monitorix.pm "$(DESTDIR)$(LIBDIR)/Monitorix.pm"
	$(INSTALL_DATA) lib/mysql.pm "$(DESTDIR)$(LIBDIR)/mysql.pm"
	$(INSTALL_DATA) lib/net.pm "$(DESTDIR)$(LIBDIR)/net.pm"
	$(INSTALL_DATA) lib/netstat.pm "$(DESTDIR)$(LIBDIR)/netstat.pm"
	$(INSTALL_DATA) lib/nfsc.pm "$(DESTDIR)$(LIBDIR)/nfsc.pm"
	$(INSTALL_DATA) lib/nfss.pm "$(DESTDIR)$(LIBDIR)/nfss.pm"
	$(INSTALL_DATA) lib/nginx.pm "$(DESTDIR)$(LIBDIR)/nginx.pm"
	$(INSTALL_DATA) lib/ntp.pm "$(DESTDIR)$(LIBDIR)/ntp.pm"
	$(INSTALL_DATA) lib/nvidia.pm "$(DESTDIR)$(LIBDIR)/nvidia.pm"
	$(INSTALL_DATA) lib/phpapc.pm "$(DESTDIR)$(LIBDIR)/phpapc.pm"
	$(INSTALL_DATA) lib/port.pm "$(DESTDIR)$(LIBDIR)/port.pm"
	$(INSTALL_DATA) lib/process.pm "$(DESTDIR)$(LIBDIR)/process.pm"
	$(INSTALL_DATA) lib/proc.pm "$(DESTDIR)$(LIBDIR)/proc.pm"
	$(INSTALL_DATA) lib/raspberrypi.pm "$(DESTDIR)$(LIBDIR)/raspberrypi.pm"
	$(INSTALL_DATA) lib/serv.pm "$(DESTDIR)$(LIBDIR)/serv.pm"
	$(INSTALL_DATA) lib/squid.pm "$(DESTDIR)$(LIBDIR)/squid.pm"
	$(INSTALL_DATA) lib/system.pm "$(DESTDIR)$(LIBDIR)/system.pm"
	$(INSTALL_DATA) lib/traffacct.pm "$(DESTDIR)$(LIBDIR)/traffacct.pm"
	$(INSTALL_DATA) lib/user.pm "$(DESTDIR)$(LIBDIR)/user.pm"
	$(INSTALL_DATA) lib/wowza.pm "$(DESTDIR)$(LIBDIR)/wowza.pm"

	$(INSTALL_DIR) "$(DESTDIR)$(LIBDIR)/reports"
	$(INSTALL_DATA) reports/ca.html "$(DESTDIR)$(LIBDIR)/reports/ca.html"
	$(INSTALL_DATA) reports/de.html "$(DESTDIR)$(LIBDIR)/reports/de.html"
	$(INSTALL_DATA) reports/en.html "$(DESTDIR)$(LIBDIR)/reports/en.html"
	$(INSTALL_DATA) reports/it.html "$(DESTDIR)$(LIBDIR)/reports/it.html"
	$(INSTALL_DATA) reports/zh_CN.html "$(DESTDIR)$(LIBDIR)/reports/zh_CN.html"

	$(INSTALL_DIR) "$(DESTDIR)$(LIBDIR)/usage"

install-docs:
	$(Q)echo -e '\033[1;32mInstalling docs...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(DOCDIR)"
	$(INSTALL_PROGRAM) docs/$(PN)-alert.sh "$(DESTDIR)$(DOCDIR)/$(PN)-alert.sh"
	$(INSTALL_PROGRAM) docs/htpasswd.pl "$(DESTDIR)$(DOCDIR)/htpasswd.pl"
	$(INSTALL_DATA) Changes "$(DESTDIR)$(DOCDIR)/Changes"
	$(INSTALL_DATA) README "$(DESTDIR)$(DOCDIR)/README"
	$(INSTALL_DATA) README.FreeBSD "$(DESTDIR)$(DOCDIR)/README.FreeBSD"
	$(INSTALL_DATA) README.nginx "$(DESTDIR)$(DOCDIR)/README.nginx"
	$(INSTALL_DATA) README.OpenBSD "$(DESTDIR)$(DOCDIR)/README.OpenBSD"
	$(INSTALL_DATA) README.NetBSD "$(DESTDIR)$(DOCDIR)/README.NetBSD"
	$(INSTALL_DATA) docs/$(PN)-lighttpd.conf "$(DESTDIR)$(DOCDIR)/$(PN)-lighttpd.conf"
	$(INSTALL_DATA) docs/$(PN)-apache.conf "$(DESTDIR)$(DOCDIR)/$(PN)-apache.conf"

install-man:
	$(Q)echo -e '\033[1;32mInstalling manpages...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(MAN5DIR)"
	$(INSTALL_DATA) man/man5/$(PN).conf.5 "$(DESTDIR)$(MAN5DIR)/$(PN).conf.5"

	$(INSTALL_DIR) "$(DESTDIR)$(MAN8DIR)"
	$(INSTALL_DATA) man/man8/$(PN).8 "$(DESTDIR)$(MAN8DIR)/$(PN).8"

install-systemd:
	$(Q)echo -e '\033[1;32mInstalling systemd files...\033[0m'
	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)"
	$(INSTALL_DIR) "$(DESTDIR)$(INITDIR_SYSTEMD)"
	$(INSTALL_DATA) docs/$(PN).service "$(DESTDIR)$(INITDIR_SYSTEMD)/$(PN).service"

install-upstart:
	$(INSTALL_DIR) "$(DESTDIR)$(CONFDIR)"
	$(INSTALL_DIR) "$(DESTDIR)$(INITDIR_UPSTART)"
	$(INSTALL_DATA) docs/$(PN).upstart "$(DESTDIR)$(INITDIR_UPSTART)/$(PN)"

## TODO: add target for other init systems

install-systemd-all: install-bin install-man install-systemd install-docs

install-upstart-all: install-bin install-man install-upstart install-docs

uninstall-bin:
	$(RM) "$(DESTDIR)$(BINDIR)/$(PN)"
	$(RM) "$(DESTDIR)$(BASEDIR)/cgi/$(PN).cgi"
	$(RM) "$(DESTDIR)$(BASEDIR)/logo_bot.png"
	$(RM) "$(DESTDIR)$(BASEDIR)/logo_top.png"
	$(RM) "$(DESTDIR)$(BASEDIR)/monitorixico.png"
	$(RM) "$(DESTDIR)$(CONFDIR)/$(PN)/$(PN).conf"
	$(RM) "$(DESTDIR)$(CONFDIR)/logrotate.d/$(PN).logrotate"
	$(RM) "$(DESTDIR)$(CONFDIR)/sysconfig//$(PN).sysconfig"
	$(RM) "$(DESTDIR)$(LIBDIR)/"*.pm
	$(RM) "$(DESTDIR)$(LIBDIR)/reports/"*.html
	$(RMD) "$(DESTDIR)$(LIBDIR)/reports"
	$(RMD) "$(DESTDIR)$(LIBDIR)/usage"
	$(RMD) "$(DESTDIR)$(LIBDIR)/"
	$(RMD) "$(DESTDIR)$(BASEDIR)/cgi"

uninstall-docs:
	$(RM) "$(DESTDIR)$(DOCDIR)/$(PN)-alert.sh"
	$(RM) "$(DESTDIR)$(DOCDIR)/htpasswd.pl"
	$(RM) "$(DESTDIR)$(DOCDIR)/Changes"
	$(RM) "$(DESTDIR)$(DOCDIR)/"README*
	$(RM) "$(DESTDIR)$(DOCDIR)/"*.conf

uninstall-man:
	$(RM) "$(DESTDIR)$(MAN5DIR)/$(PN).conf.5"
	$(RM) "$(DESTDIR)$(MAN8DIR)/$(PN).8"

uninstall-systemd:
	$(RM) "$(DESTDIR)$(INITDIR_SYSTEMD)/$(PN).service"

uninstall-upstart:
	$(RM) "$(DESTDIR)$(INITDIR_UPSTART)/$(PN)"

uninstall-systemd-all: uninstall-bin uninstall-man uninstall-docs uninstall-systemd

uninstall-upstart-all: uninstall-bin uninstall-man uninstall-docs uninstall-upstart

uninstall:
	$(Q)echo "run one of the following:"
	$(Q)echo "  make uninstall-systemd-all (systemd based systems)"
	$(Q)echo "  make uninstall-upstart-all (upstart based systems)"
	$(Q)echo
	$(Q)echo "or check out the Makefile for specific rules"

clean:
	$(RM) $(PN)

.PHONY: help install-bin install-man install-docs install-systemd install-upstart install-systemd-all install-upstart-all install uninstall-bin uninstall-man uninstall-docs uninstall-systemd uninstall-upstart uninstall-systemd-all uninstall-upstart-all uninstall clean
