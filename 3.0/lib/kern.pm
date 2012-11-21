package kern;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(kern_init kern_update kern_cgi);

sub kern_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		eval {
			RRDs::create($rrd,
				"--step=60",
				"DS:kern_user:GAUGE:120:0:100",
				"DS:kern_nice:GAUGE:120:0:100",
				"DS:kern_sys:GAUGE:120:0:100",
				"DS:kern_idle:GAUGE:120:0:100",
				"DS:kern_iow:GAUGE:120:0:100",
				"DS:kern_irq:GAUGE:120:0:100",
				"DS:kern_sirq:GAUGE:120:0:100",
				"DS:kern_steal:GAUGE:120:0:100",
				"DS:kern_guest:GAUGE:120:0:100",
				"DS:kern_cs:COUNTER:120:0:U",
				"DS:kern_dentry:GAUGE:120:0:100",
				"DS:kern_file:GAUGE:120:0:100",
				"DS:kern_inode:GAUGE:120:0:100",
				"DS:kern_forks:COUNTER:120:0:U",
				"DS:kern_vforks:COUNTER:120:0:U",
				"DS:kern_val03:GAUGE:120:0:100",
				"DS:kern_val04:GAUGE:120:0:100",
				"DS:kern_val05:GAUGE:120:0:100",
				"RRA:AVERAGE:0.5:1:1440",
				"RRA:AVERAGE:0.5:30:336",
				"RRA:AVERAGE:0.5:60:744",
				"RRA:AVERAGE:0.5:1440:365",
				"RRA:MIN:0.5:1:1440",
				"RRA:MIN:0.5:30:336",
				"RRA:MIN:0.5:60:744",
				"RRA:MIN:0.5:1440:365",
				"RRA:MAX:0.5:1:1440",
				"RRA:MAX:0.5:30:336",
				"RRA:MAX:0.5:60:744",
				"RRA:MAX:0.5:1440:365",
				"RRA:LAST:0.5:1:1440",
				"RRA:LAST:0.5:30:336",
				"RRA:LAST:0.5:60:744",
				"RRA:LAST:0.5:1440:365",
			);
		};
		my $err = RRDs::error;
		if($@ || $err) {
			logger("$@") unless !$@;
			if($err) {
				logger("ERROR: while creating $rrd: $err");
				if($err eq "RRDs::error") {
					logger("... is the RRDtool Perl package installed?");
				}
			}
			return;
		}
	}

	$config->{kern_hist} = ();
	push(@{$config->{func_update}}, $package);
	if($debug) {
		logger("$myself: Ok");
	}
}

sub kern_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	my $user;
	my $nice;
	my $sys;
	my $idle;
	my $iow;
	my $irq;
	my $sirq;
	my $steal;
	my $guest;
	my $cs = 0;
	my $dentry;
	my $file;
	my $inode;
	my $forks = 0;
	my $vforks = 0;
	my $val03 = 0;
	my $val04 = 0;
	my $val05 = 0;
	
	my $lastuser = 0;
	my $lastnice = 0;
	my $lastsys = 0;
	my $lastidle = 0;
	my $lastiow = 0;
	my $lastirq = 0;
	my $lastsirq = 0;
	my $laststeal = 0;
	my $lastguest = 0;

	my $rrdata = "N";

	if($config->{kern_hist}->{kernel}) {
		(undef, $lastuser, $lastnice, $lastsys, $lastidle, $lastiow, $lastirq, $lastsirq, $laststeal, $lastguest) = split(' ', $config->{kern_hist}->{kernel});
	}

	if($config->{os} eq "Linux") {
		open(IN, "/proc/stat");
		while(<IN>) {
			if(/^cpu /) {
				(undef, $user, $nice, $sys, $idle, $iow, $irq, $sirq, $steal, $guest) = split(' ', $_);
				$config->{kern_hist}->{kernel} = $_;
				next;
			}
			if(/^ctxt (\d+)$/) {
				# avoid initial spike
				$cs = int($1) unless !$config->{kern_hist}->{cs};
				$config->{kern_hist}->{cs} = int($1) unless $config->{kern_hist}->{cs};
				next;
			}
			if(/^processes (\d+)$/) {
				# avoid initial spike
				$forks = int($1) unless !$config->{kern_hist}->{forks};
				$config->{kern_hist}->{forks} = int($1) unless $config->{kern_hist}->{forks};
				$vforks = 0;
				last;
			}
		}
		close(IN);
		open(IN, "/proc/sys/fs/dentry-state");
			while(<IN>) {
				if(/^(\d+)\s+(\d+)\s+/) {
					$dentry = ($1 * 100) / ($1 + $2);
				}
			}
		close(IN);
		open(IN, "/proc/sys/fs/file-nr");
			while(<IN>) {
				if(/^(\d+)\s+\d+\s+(\d+)$/) {
					$file = ($1 * 100) / $2;
				}
			}
		close(IN);
		open(IN, "/proc/sys/fs/inode-nr");
			while(<IN>) {
				if(/^(\d+)\s+(\d+)$/) {
					$inode = ($1 * 100) / ($1 + $2);
				}
			}
		close(IN);
	} elsif($config->{os} eq "FreeBSD") {
		my $max;
		my $num;
		my $data;

		my $cptime = `sysctl -n kern.cp_time`;
		chomp($cptime);
		my @tmp = split(' ', $cptime);
		($user, $nice, $sys, $iow, $idle) = @tmp;

		$config->{kern_hist}->{kernel} = join(' ', "cpu", $user, $nice, $sys, $idle, $iow);
		$data = `sysctl -n vm.stats.sys.v_swtch`;
		chomp($data);
		$cs = int($data) unless !$config->{kern_hist}->{cs};
		$config->{kern_hist}->{cs} = int($data) unless $config->{kern_hist}->{cs};

		$data = `sysctl -n vm.stats.vm.v_forks`;
		chomp($data);
		$forks = int($data) unless !$config->{kern_hist}->{forks};
		$config->{kern_hist}->{forks} = int($data) unless $config->{kern_hist}->{forks};

		$data = `sysctl -n vm.stats.vm.v_vforks`;
		chomp($data);
		$vforks = int($data) unless !$config->{kern_hist}->{vforks};
		$config->{kern_hist}->{vforks} = int($data) unless $config->{kern_hist}->{vforks};

		$max = `sysctl -n kern.maxfiles`;
		chomp($max);
		$num = `sysctl -n kern.openfiles`;
		chomp($num);
		$file = ($num * 100) / $max;

		$max = `sysctl -n kern.maxvnodes`;
		chomp($max);
		$num = `sysctl -n vfs.numvnodes`;
		chomp($num);
		$inode = ($num * 100) / $max;
	} elsif($config->{os} eq "OpenBSD") {
		my $max;
		my $num;
		my $data;

		my $cptime = `sysctl -n kern.cp_time`;
		chomp($cptime);
		my @tmp = split(',', $cptime);
		($user, $nice, $sys, $iow, $idle) = @tmp;
		$config->{kern_hist}->{kernel} = join(' ', "cpu", $user, $nice, $sys, $idle, $iow);
		open(IN, "vmstat -s |");
		while(<IN>) {
			if(/^\s*(\d+) cpu context switches$/) {
				$cs = int($1) unless !$config->{kern_hist}->{cs};
				$config->{kern_hist}->{cs} = int($1) unless $config->{kern_hist}->{cs};
				last;
			}
		}
		close(IN);

		$data = `sysctl -n kern.forkstat.forks`;
		chomp($data);
		$forks = int($data) unless !$config->{kern_hist}->{forks};
		$config->{kern_hist}->{forks} = int($data) unless $config->{kern_hist}->{forks};

		$data = `sysctl -n kern.forkstat.vforks`;
		chomp($data);
		$vforks = int($data) unless !$config->{kern_hist}->{vforks};
		$config->{kern_hist}->{vforks} = int($data) unless $config->{kern_hist}->{vforks};

		$max = `sysctl -n kern.maxfiles`;
		chomp($max);
		$num = `sysctl -n kern.nfiles`;
		chomp($num);
		$file = ($num * 100) / $max;

		$max = `sysctl -n kern.maxvnodes`;
		chomp($max);
		$data = `sysctl -n kern.malloc.kmemstat.vnodes`;
		($num) = ($data =~ m/^\(inuse = (\d+), /);
		$inode = ($num * 100) / $max;
	} elsif($config->{os} eq "NetBSD") {
		my $max;
		my $num;
		my $data;

		my $cptime = `sysctl -n kern.cp_time`;
		chomp($cptime);
		my @tmp = ($cptime =~ m/user = (\d+), nice = (\d+), sys = (\d+), intr = (\d+), idle = (\d+)/);
		($user, $nice, $sys, $iow, $idle) = @tmp;
		$config->{kern_hist}->{kernel} = join(' ', "cpu", $user, $nice, $sys, $idle, $iow);
		open(IN, "vmstat -s |");
		while(<IN>) {
			if(/^\s*(\d+) CPU context switches$/) {
				$cs = int($1) unless !$config->{kern_hist}->{cs};
				$config->{kern_hist}->{cs} = int($1) unless $config->{kern_hist}->{cs};
				next;
			}
			if(/^\s*(\d+) forks total$/) {
				$forks = int($1) unless !$config->{kern_hist}->{forks};
				$config->{kern_hist}->{forks} = int($1) unless $config->{kern_hist}->{forks};
				next;
			}
		}
		close(IN);

		$vforks = 0;

		open(IN, "pstat -T |");
		while(<IN>) {
			if(/^(\d+)\/(\d+) files$/) {
				$file = ($1 * 100) / $2;
			}
		}
		close(IN);

		$inode = 0;
	}

	# Linux 2.4, early Linux 2.6 versions and other systems don't have
	# these values.
	$iow = 0 unless $iow;
	$irq = 0 unless $irq;
	$sirq = 0 unless $sirq;
	$steal = 0 unless $sirq;
	$guest = 0 unless $guest;
	$lastiow = 0 unless $lastiow;
	$lastirq = 0 unless $lastirq;
	$lastsirq = 0 unless $lastsirq;
	$laststeal = 0 unless $lastsirq;
	$lastguest = 0 unless $lastguest;

	if($user >= $lastuser && $nice >= $lastnice && $sys >= $lastsys && $idle >= $lastidle && $iow >= $lastiow && $irq >= $lastirq && $sirq >= $lastsirq && $steal >= $laststeal && $guest >= $lastguest) {
		my $user_ = $user - $lastuser;
		my $nice_ = $nice - $lastnice;
		my $sys_ = $sys - $lastsys;
		my $idle_ = $idle - $lastidle;
		my $iow_ = $iow - $lastiow;
		my $irq_ = $irq - $lastirq;
		my $sirq_ = $sirq - $lastsirq;
		my $steal_ = $steal - $laststeal;
		my $guest_ = $guest - $lastguest;
		my $total = $user_ + $nice_ + $sys_ + $idle_ + $iow_ + $irq_ + $sirq_ + $steal_ + $guest_;
		$user = ($user_ * 100) / $total;
		$nice = ($nice_ * 100) / $total;
		$sys = ($sys_ * 100) / $total;
		$idle = ($idle_ * 100) / $total;
		$iow = ($iow_ * 100) / $total;
		$irq = ($irq_ * 100) / $total;
		$sirq = ($sirq_ * 100) / $total;
		$steal = ($steal_ * 100) / $total;
		$guest = ($guest_ * 100) / $total;
	} else {
		$user = "nan";
		$nice = "nan";
		$sys = "nan";
		$idle = "nan";
		$iow = "nan";
		$irq = "nan";
		$sirq = "nan";
		$steal = "nan";
		$guest = "nan";
	}

	$rrdata .= ":$user:$nice:$sys:$idle:$iow:$irq:$sirq:$steal:$guest:$cs:$dentry:$file:$inode:$forks:$vforks:$val03:$val04:$val05";
	RRDs::update($rrd, $rrdata);
	if($debug) {
		logger("$myself: $rrdata");
	}
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub kern_cgi {
	my ($package, $config, $cgi) = @_;

	my %kern = %{$config->{kern}};
	my @rigid = split(',', $kern{rigid});
	my @limit = split(',', $kern{limit});
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};

	my $u = "";
	my $width;
	my $height;
	my @riglim;
	my @tmp;
	my @tmpz;
	my $vlabel;
	my $n;
	my $err;

	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $PNG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};

	$title = !$silent ? $title : "";

	if($silent eq "yes" || $silent eq "imagetag") {
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "_";
	}
	if($silent eq "imagetagbig") {
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "";
	}

	my $PNG1 = $u . $package . "1." . $tf->{when} . ".png";
	my $PNG2 = $u . $package . "2." . $tf->{when} . ".png";
	my $PNG3 = $u . $package . "3." . $tf->{when} . ".png";
	my $PNG1z = $u . $package . "1z." . $tf->{when} . ".png";
	my $PNG2z = $u . $package . "2z." . $tf->{when} . ".png";
	my $PNG3z = $u . $package . "3z." . $tf->{when} . ".png";
	unlink ("$PNG_DIR" . "$PNG1",
		"$PNG_DIR" . "$PNG2",
		"$PNG_DIR" . "$PNG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$PNG_DIR" . "$PNG1z",
			"$PNG_DIR" . "$PNG2z",
			"$PNG_DIR" . "$PNG3z");
	}

	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			main::graph_header($title, 2);
			print("    <tr>\n");
			print("    <td bgcolor='$colors->{title_bg_color}'>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"AVERAGE",
			"-r $tf->{res}");
		$err = RRDs::error;
		print("ERROR: while fetching $rrd: $err\n") if $err;
		print("    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		print("       Kernel usage                                                                           VFS usage\n");
		print("Time   User   Nice    Sys   Idle   I/Ow    IRQ   sIRQ  Steal  Guest   Ctxt.Sw  Forks  VForks  dentry   file  inode\n");
		print("------------------------------------------------------------------------------------------------------------------\n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			my ($usr, $nic, $sys, $idle, $iow, $irq, $sirq, $steal, $guest, $cs, $dentry, $file, $inode, $forks, $vforks) = @$line;
			@row = ($usr, $nic, $sys, $idle, $iow, $irq, $sirq, $steal, $guest, $cs, $forks, $vforks, $dentry, $file, $inode);
			$time = $time - (1 / $tf->{ts});
			printf(" %2d$tf->{tc}  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%  %4.1f%%   %7d %6d  %6d   %4.1f%%  %4.1f%%  %4.1f%% \n", $time, @row);
		}
		print("    </pre>\n");
		if($title) {
			print("    </td>\n");
			print("    </tr>\n");
			main::graph_footer();
		}
		print("  <br>\n");
		return;
	}

	if($title) {
		main::graph_header($title, 2);
	}
	if(trim($rigid[0]) eq 1) {
		push(@riglim, "--upper-limit=" . trim($limit[0]));
	} else {
		if(trim($rigid[0]) eq 2) {
			push(@riglim, "--upper-limit=" . trim($limit[0]));
			push(@riglim, "--rigid");
		}
	}
	if(lc($kern{graph_mode}) eq "r") {
		$vlabel = "Percent (%)";
		if(lc($kern{list}->{user}) eq "y") {
			push(@tmp, "AREA:user#4444EE:user");
			push(@tmpz, "AREA:user#4444EE:user");
			push(@tmp, "GPRINT:user:LAST:      Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:MAX:    Max\\: %4.1lf%%\\n");
		}
		if(lc($kern{list}->{nice}) eq "y") {
			push(@tmp, "AREA:nice#EEEE44:nice");
			push(@tmpz, "AREA:nice#EEEE44:nice");
			push(@tmp, "GPRINT:nice:LAST:      Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:MAX:    Max\\: %4.1lf%%\\n");
		}
		if(lc($kern{list}->{sys}) eq "y") {
			push(@tmp, "AREA:sys#44EEEE:system");
			push(@tmpz, "AREA:sys#44EEEE:system");
			push(@tmp, "GPRINT:sys:LAST:    Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:MAX:    Max\\: %4.1lf%%\\n");
		}
		if(lc($kern{list}->{iow}) eq "y") {
			push(@tmp, "AREA:iow#EE44EE:I/O wait");
			push(@tmpz, "AREA:iow#EE44EE:I/O wait");
			push(@tmp, "GPRINT:iow:LAST:  Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($config->{os} eq "Linux") {
			if(lc($kern{list}->{irq}) eq "y") {
				push(@tmp, "AREA:irq#888888:IRQ");
				push(@tmpz, "AREA:irq#888888:IRQ");
				push(@tmp, "GPRINT:irq:LAST:       Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:MAX:    Max\\: %4.1lf%%\\n");
			}
			if(lc($kern{list}->{sirq}) eq "y") {
				push(@tmp, "AREA:sirq#E29136:softIRQ");
				push(@tmpz, "AREA:sirq#E29136:softIRQ");
				push(@tmp, "GPRINT:sirq:LAST:   Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:MAX:    Max\\: %4.1lf%%\\n");
			}
			if(lc($kern{list}->{steal}) eq "y") {
				push(@tmp, "AREA:steal#44EE44:steal");
				push(@tmpz, "AREA:steal#44EE44:steal");
				push(@tmp, "GPRINT:steal:LAST:     Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:MAX:    Max\\: %4.1lf%%\\n");
			}
			if(lc($kern{list}->{guest}) eq "y") {
				push(@tmp, "AREA:guest#448844:guest");
				push(@tmpz, "AREA:guest#448844:guest");
				push(@tmp, "GPRINT:guest:LAST:     Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:MAX:    Max\\: %4.1lf%%\\n");
			}
			push(@tmp, "LINE1:guest#1F881F") unless lc($kern{list}->{guest} ne "y");
			push(@tmpz, "LINE1:guest#1F881F") unless lc($kern{list}->{guest} ne "y");
			push(@tmp, "LINE1:steal#00EE00") unless lc($kern{list}->{steal} ne "y");
			push(@tmpz, "LINE1:steal#00EE00") unless lc($kern{list}->{steal} ne "y");
			push(@tmp, "LINE1:sirq#D86612") unless lc($kern{list}->{sirq} ne "y");
			push(@tmpz, "LINE1:sirq#D86612") unless lc($kern{list}->{sirq} ne "y");
			push(@tmp, "LINE1:irq#CCCCCC") unless lc($kern{list}->{irq} ne "y");
			push(@tmpz, "LINE1:irq#CCCCCC") unless lc($kern{list}->{irq} ne "y");
		}
		push(@tmp, "LINE1:iow#EE00EE") unless lc($kern{list}->{iow} ne "y");
		push(@tmpz, "LINE1:iow#EE00EE") unless lc($kern{list}->{iow} ne "y");
		push(@tmp, "LINE1:sys#00EEEE") unless lc($kern{list}->{sys} ne "y");
		push(@tmpz, "LINE1:sys#00EEEE") unless lc($kern{list}->{sys} ne "y");
		push(@tmp, "LINE1:nice#EEEE00") unless lc($kern{list}->{nice} ne "y");
		push(@tmpz, "LINE1:nice#EEEE00") unless lc($kern{list}->{nice} ne "y");
		push(@tmp, "LINE1:user#0000EE") unless lc($kern{list}->{user} ne "y");
		push(@tmpz, "LINE1:user#0000EE") unless lc($kern{list}->{user} ne "y");
	} else {
		$vlabel = "Stacked Percent (%)";
		push(@tmp, "CDEF:s_nice=user,nice,+");
		push(@tmpz, "CDEF:s_nice=user,nice,+");
		push(@tmp, "CDEF:s_sys=s_nice,sys,+");
		push(@tmpz, "CDEF:s_sys=s_nice,sys,+");
		push(@tmp, "CDEF:s_iow=s_sys,iow,+");
		push(@tmpz, "CDEF:s_iow=s_sys,iow,+");
		if($config->{os} eq "Linux") {
			push(@tmp, "CDEF:s_irq=s_iow,irq,+");
			push(@tmpz, "CDEF:s_irq=s_iow,irq,+");
			push(@tmp, "CDEF:s_sirq=s_irq,sirq,+");
			push(@tmpz, "CDEF:s_sirq=s_irq,sirq,+");
			push(@tmp, "CDEF:s_steal=s_sirq,steal,+");
			push(@tmpz, "CDEF:s_steal=s_sirq,steal,+");
			push(@tmp, "CDEF:s_guest=s_steal,guest,+");
			push(@tmpz, "CDEF:s_guest=s_steal,guest,+");
			if(lc($kern{list}->{guest}) eq "y") {
				push(@tmp, "AREA:s_guest#448844:guest");
				push(@tmpz, "AREA:s_guest#448844:guest");
				push(@tmp, "GPRINT:guest:LAST:     Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:guest:MAX:    Max\\: %4.1lf%%\\n");
			}
			if(lc($kern{list}->{steal}) eq "y") {
				push(@tmp, "AREA:s_steal#44EE44:steal");
				push(@tmpz, "AREA:s_steal#44EE44:steal");
				push(@tmp, "GPRINT:steal:LAST:     Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:steal:MAX:    Max\\: %4.1lf%%\\n");
			}
			if(lc($kern{list}->{sirq}) eq "y") {
				push(@tmp, "AREA:s_sirq#E29136:softIRQ");
				push(@tmpz, "AREA:s_sirq#E29136:softIRQ");
				push(@tmp, "GPRINT:sirq:LAST:   Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:sirq:MAX:    Max\\: %4.1lf%%\\n");
			}
			if(lc($kern{list}->{irq}) eq "y") {
				push(@tmp, "AREA:s_irq#888888:IRQ");
				push(@tmpz, "AREA:s_irq#888888:IRQ");
				push(@tmp, "GPRINT:irq:LAST:       Current\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:AVERAGE:    Average\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:MIN:    Min\\: %4.1lf%%");
				push(@tmp, "GPRINT:irq:MAX:    Max\\: %4.1lf%%\\n");
			}
		}	
		if(lc($kern{list}->{iow}) eq "y") {
			push(@tmp, "AREA:s_iow#EE44EE:I/O wait");
			push(@tmpz, "AREA:s_iow#EE44EE:I/O wait");
			push(@tmp, "GPRINT:iow:LAST:  Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:iow:MAX:    Max\\: %4.1lf%%\\n");
		}
		if(lc($kern{list}->{sys}) eq "y") {
			push(@tmp, "AREA:s_sys#44EEEE:system");
			push(@tmpz, "AREA:s_sys#44EEEE:system");
			push(@tmp, "GPRINT:sys:LAST:    Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:sys:MAX:    Max\\: %4.1lf%%\\n");
		}
		if(lc($kern{list}->{nice}) eq "y") {
			push(@tmp, "AREA:s_nice#EEEE44:nice");
			push(@tmpz, "AREA:s_nice#EEEE44:nice");
			push(@tmp, "GPRINT:nice:LAST:      Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:nice:MAX:    Max\\: %4.1lf%%\\n");
		}
		if(lc($kern{list}->{user}) eq "y") {
			push(@tmp, "AREA:user#4444EE:user");
			push(@tmpz, "AREA:user#4444EE:user");
			push(@tmp, "GPRINT:user:LAST:      Current\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:AVERAGE:    Average\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:MIN:    Min\\: %4.1lf%%");
			push(@tmp, "GPRINT:user:MAX:    Max\\: %4.1lf%%\\n");
		}
		if($config->{os} eq "Linux") {
			push(@tmp, "LINE1:s_guest#1F881F");
			push(@tmpz, "LINE1:s_guest#1F881F");
			push(@tmp, "LINE1:s_steal#00EE00");
			push(@tmpz, "LINE1:s_steal#00EE00");
			push(@tmp, "LINE1:s_sirq#D86612");
			push(@tmpz, "LINE1:s_sirq#D86612");
			push(@tmp, "LINE1:s_irq#CCCCCC");
			push(@tmpz, "LINE1:s_irq#CCCCCC");
		}	
		push(@tmp, "LINE1:s_iow#EE00EE");
		push(@tmpz, "LINE1:s_iow#EE00EE");
		push(@tmp, "LINE1:s_sys#00EEEE");
		push(@tmpz, "LINE1:s_sys#00EEEE");
		push(@tmp, "LINE1:s_nice#EEEE00");
		push(@tmpz, "LINE1:s_nice#EEEE00");
		push(@tmp, "LINE1:user#0000EE");
		push(@tmpz, "LINE1:user#0000EE");
	}
	if(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD", "NetBSD")) {
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}

	if($title) {
		print("    <tr>\n");
		print("    <td bgcolor='$colors->{title_bg_color}'>\n");
	}
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG1",
		"--title=$config->{graphs}->{_kern1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=$vlabel",
		"--width=$width",
		"--height=$height",
		@riglim,
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		"DEF:user=$rrd:kern_user:AVERAGE",
		"DEF:nice=$rrd:kern_nice:AVERAGE",
		"DEF:sys=$rrd:kern_sys:AVERAGE",
		"DEF:iow=$rrd:kern_iow:AVERAGE",
		"DEF:irq=$rrd:kern_irq:AVERAGE",
		"DEF:sirq=$rrd:kern_sirq:AVERAGE",
		"DEF:steal=$rrd:kern_steal:AVERAGE",
		"DEF:guest=$rrd:kern_guest:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG1z",
			"--title=$config->{graphs}->{_kern1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=$vlabel",
			"--width=$width",
			"--height=$height",
			@riglim,
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			"DEF:user=$rrd:kern_user:AVERAGE",
			"DEF:nice=$rrd:kern_nice:AVERAGE",
			"DEF:sys=$rrd:kern_sys:AVERAGE",
			"DEF:iow=$rrd:kern_iow:AVERAGE",
			"DEF:irq=$rrd:kern_irq:AVERAGE",
			"DEF:sirq=$rrd:kern_sirq:AVERAGE",
			"DEF:steal=$rrd:kern_steal:AVERAGE",
			"DEF:guest=$rrd:kern_guest:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /kern1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNG1z . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNG1z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG1 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG1 . "'>\n");
		}
	}
	if($title) {
		print("    </td>\n");
		print("    <td valign='top' bgcolor='" . $colors->{title_bg_color} . "'>\n");
	}

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:cs#44AAEE:Context switches");
	push(@tmpz, "AREA:cs#44AAEE:Context switches");
	push(@tmp, "GPRINT:cs:LAST:     Current\\: %6.0lf\\n");
	push(@tmp, "AREA:forks#4444EE:Forks");
	push(@tmpz, "AREA:forks#4444EE:Forks");
	push(@tmp, "GPRINT:forks:LAST:                Current\\: %6.0lf\\n");
	push(@tmp, "LINE1:cs#00EEEE");
	push(@tmp, "LINE1:forks#0000EE");
	push(@tmpz, "LINE1:cs#00EEEE");
	push(@tmpz, "LINE1:forks#0000EE");
	if($config->{os} eq "FreeBSD" || $config->{os} eq "OpenBSD") {
		push(@tmp, "AREA:vforks#EE4444:VForks");
		push(@tmpz, "AREA:vforks#EE4444:VForks");
		push(@tmp, "GPRINT:vforks:LAST:               Current\\: %6.0lf\\n");
		push(@tmp, "LINE1:vforks#EE0000");
		push(@tmpz, "LINE1:vforks#EE0000");
	}

	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG2",
		"--title=$config->{graphs}->{_kern2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=CS & forks/s",
		"--width=$width",
		"--height=$height",
		"--lower-limit=0",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:cs=$rrd:kern_cs:AVERAGE",
		"DEF:forks=$rrd:kern_forks:AVERAGE",
		"DEF:vforks=$rrd:kern_vforks:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG2z",
			"--title=$config->{graphs}->{_kern2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=CS & forks/s",
			"--width=$width",
			"--height=$height",
			"--lower-limit=0",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:cs=$rrd:kern_cs:AVERAGE",
			"DEF:forks=$rrd:kern_forks:AVERAGE",
			"DEF:vforks=$rrd:kern_vforks:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /kern2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNG2z . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNG2z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG2 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG2 . "'>\n");
		}
	}

	undef(@tmp);
	undef(@tmpz);
	push(@tmp, "AREA:inode#4444EE:inode");
	push(@tmpz, "AREA:inode#4444EE:inode");
	push(@tmp, "GPRINT:inode:LAST:                Current\\:  %4.1lf%%\\n");
	if($config->{os} eq "Linux") {
		push(@tmp, "AREA:dentry#EEEE44:dentry");
		push(@tmpz, "AREA:dentry#EEEE44:dentry");
		push(@tmp, "GPRINT:dentry:LAST:               Current\\:  %4.1lf%%\\n");
	}
	push(@tmp, "AREA:file#EE44EE:file");
	push(@tmpz, "AREA:file#EE44EE:file");
	push(@tmp, "GPRINT:file:LAST:                 Current\\:  %4.1lf%%\\n");
	push(@tmp, "LINE2:inode#0000EE");
	push(@tmpz, "LINE2:inode#0000EE");
	if($config->{os} eq "Linux") {
		push(@tmp, "LINE2:dentry#EEEE00");
		push(@tmpz, "LINE2:dentry#EEEE00");
	}	
	push(@tmp, "LINE2:file#EE00EE");
	push(@tmpz, "LINE2:file#EE00EE");
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
		@tmp = @tmpz;
		push(@tmp, "COMMENT: \\n");
		push(@tmp, "COMMENT: \\n");
	}
	RRDs::graph("$PNG_DIR" . "$PNG3",
		"--title=$config->{graphs}->{_kern3}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=PNG",
		"--vertical-label=Percent (%)",
		"--width=$width",
		"--height=$height",
		"--upper-limit=100",
		"--lower-limit=0",
		"--rigid",
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		"DEF:dentry=$rrd:kern_dentry:AVERAGE",
		"DEF:file=$rrd:kern_file:AVERAGE",
		"DEF:inode=$rrd:kern_inode:AVERAGE",
		@tmp);
	$err = RRDs::error;
	print("ERROR: while graphing $PNG_DIR" . "$PNG3: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		RRDs::graph("$PNG_DIR" . "$PNG3z",
			"--title=$config->{graphs}->{_kern3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=PNG",
			"--vertical-label=Percent (%)",
			"--width=$width",
			"--height=$height",
			"--upper-limit=100",
			"--lower-limit=0",
			"--rigid",
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			"DEF:dentry=$rrd:kern_dentry:AVERAGE",
			"DEF:file=$rrd:kern_file:AVERAGE",
			"DEF:inode=$rrd:kern_inode:AVERAGE",
			@tmpz);
		$err = RRDs::error;
		print("ERROR: while graphing $PNG_DIR" . "$PNG3z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /kern3/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				print("      <a href=\"" . $config->{url} . $config->{imgs_dir} . $PNG3z . "\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
			else {
				print("      <a href=\"javascript:void(window.open('" . $config->{url} . $config->{imgs_dir} . $PNG3z . "','','width=" . ($width + 115) . ",height=" . ($height + 100) . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . $config->{imgs_dir} . $PNG3 . "' border='0'></a>\n");
			}
		} else {
			print("      <img src='" . $config->{url} . $config->{imgs_dir} . $PNG3 . "'>\n");
		}
	}

	if($title) {
		print("    </td>\n");
		print("    </tr>\n");
		main::graph_footer();
	}
	print("  <br>\n");
	return;
}

1;
