#!/usr/bin/perl
use v5.14;
my $initSystem;
say "[start initialization]";
print "do use systemd (y/n)[n]:";
my $answer = <STDIN>;
chomp $answer;
if($answer eq "y")
{
	$initSystem="systemd";
	say "create initialization for systemd";
	system("cp ./docs/monitorix.service /usr/lib/systemd/system");
}
else
{
	say "[no]";
}
say "[create needed folders]";
mkdir "/usr/share/monitorix";
mkdir "/usr/share/monitorix/cgi";
mkdir "/usr/share/monitorix/imgs";
mkdir "/var/lib/monitorix";
mkdir "/usr/lib/monitorix";
say "[copy needed files]";
system("cp monitorix.cgi /usr/share/monitorix/cgi");
system("cp *.png /usr/share/monitorix");
system("cp monitorix /usr/share/monitorix");
system("cp monitorix.conf /usr/share/monitorix");
system("cp ./lib/*.pm /usr/lib/monitorix");
say "[create permitions]";
system("chmod 0777 /usr/share/monitorix/imgs");
say "-"x10;
say "[create htpasswd]";
print "username:>";
my $username = <STDIN>;
chomp $username;
system("echo -n $username: > /usr/share/monitorix/htpasswd");
print "password:>";
my $password = <STDIN>;
chomp $password;
system ("openssl passwd -crypt -salt $username $password >> /usr/share/monitorix/htpasswd");
say "-"x10;
say "[finish]";
