# rpm spec for Monitorix
#

Summary: Monitorix is a system monitoring tool
Name: monitorix
Version: 3.13.1
Release: 1%{?dist}
License: GPL
Group: Applications/System
URL: http://www.monitorix.org
Packager: Jordi Sanfeliu <jordi@fibranet.cat>

Source: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
BuildArch: noarch

Requires: rrdtool
Requires: perl
Requires: perl-libwww-perl
Requires: perl-MailTools
Requires: perl-MIME-Lite
Requires: perl-DBI
Requires: perl-XML-Simple
Requires: perl-XML-LibXML
Requires: perl-Config-General
Requires: perl-HTTP-Server-Simple
Requires: perl-IO-Socket-SSL

%description
Monitorix is a free, open source, lightweight system monitoring tool designed
to monitor as many services and system resources as possible. It has been
created to be used under production Linux/UNIX servers, but due to its
simplicity and small size may also be used on embedded devices as well. 

%prep
%setup

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_initrddir}
install -m 0755 docs/monitorix.init %{buildroot}%{_initrddir}/monitorix
mkdir -p %{buildroot}%{_sysconfdir}/logrotate.d
install -m 0644 docs/monitorix.logrotate %{buildroot}%{_sysconfdir}/logrotate.d/monitorix
mkdir -p %{buildroot}%{_sysconfdir}/sysconfig
install -m 0644 docs/monitorix.sysconfig %{buildroot}%{_sysconfdir}/sysconfig/monitorix
mkdir -p %{buildroot}%{_sysconfdir}/monitorix
mkdir -p %{buildroot}%{_sysconfdir}/monitorix/conf.d
install -m 0644 monitorix.conf %{buildroot}%{_sysconfdir}/monitorix/monitorix.conf
mkdir -p %{buildroot}%{_bindir}
install -m 0755 monitorix %{buildroot}%{_bindir}/monitorix
mkdir -p %{buildroot}%{_libdir}/monitorix
install -m 0644 lib/*.pm %{buildroot}%{_libdir}/monitorix
mkdir -p %{buildroot}%{_localstatedir}/lib/monitorix/www
install -m 0644 logo_top.png %{buildroot}%{_localstatedir}/lib/monitorix/www
install -m 0644 logo_bot.png %{buildroot}%{_localstatedir}/lib/monitorix/www
install -m 0644 monitorixico.png %{buildroot}%{_localstatedir}/lib/monitorix/www
mkdir -p %{buildroot}%{_localstatedir}/lib/monitorix/www/imgs
mkdir -p %{buildroot}%{_localstatedir}/lib/monitorix/www/cgi
install -m 0755 monitorix.cgi %{buildroot}%{_localstatedir}/lib/monitorix/www/cgi
mkdir -p %{buildroot}%{_localstatedir}/lib/monitorix/www/css
install -m 0644 css/*.css %{buildroot}%{_localstatedir}/lib/monitorix/www/css
mkdir -p %{buildroot}%{_localstatedir}/lib/monitorix/reports
install -m 0644 reports/*.html %{buildroot}%{_localstatedir}/lib/monitorix/reports
mkdir -p %{buildroot}%{_localstatedir}/lib/monitorix/usage
mkdir -p %{buildroot}%{_mandir}/man5
mkdir -p %{buildroot}%{_mandir}/man8
install -m 0644 man/man5/monitorix.conf.5 %{buildroot}%{_mandir}/man5
install -m 0644 man/man8/monitorix.8 %{buildroot}%{_mandir}/man8

%clean
rm -rf %{buildroot}

%post
/sbin/chkconfig --add monitorix

%files
%defattr(-, root, root)
%{_initrddir}/monitorix
%config(noreplace) %{_sysconfdir}/logrotate.d/monitorix
%config(noreplace) %{_sysconfdir}/sysconfig/monitorix
%config(noreplace) %{_sysconfdir}/monitorix/monitorix.conf
%attr(755,root,root) %{_sysconfdir}/monitorix/conf.d
%{_bindir}/monitorix
%{_libdir}/monitorix/*.pm
%{_localstatedir}/lib/monitorix/www/logo_top.png
%{_localstatedir}/lib/monitorix/www/logo_bot.png
%{_localstatedir}/lib/monitorix/www/monitorixico.png
%{_localstatedir}/lib/monitorix/www/cgi/monitorix.cgi
%{_localstatedir}/lib/monitorix/www/css/*.css
%attr(755,root,root) %{_localstatedir}/lib/monitorix/www/imgs
%attr(755,root,root) %{_localstatedir}/lib/monitorix/usage
%{_localstatedir}/lib/monitorix/reports/*.html
%doc %{_mandir}/man5/monitorix.conf.5.gz
%doc %{_mandir}/man8/monitorix.8.gz
%doc Changes COPYING README README.nginx README.BSD docs/monitorix-alert.sh docs/monitorix-apache.conf docs/monitorix-lighttpd.conf docs/monitorix.service docs/htpasswd.pl

%changelog
* Thu Sep 01 2005 Jordi Sanfeliu <jordi@fibranet.cat>
- Release 0.7.8.
- First public release.
- All changes are described in the Changes file.
