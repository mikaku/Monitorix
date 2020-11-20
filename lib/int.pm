#
# Monitorix - A lightweight system monitoring tool.
#
# Copyright (C) 2005-2020 by Jordi Sanfeliu <jordi@fibranet.cat>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

package int;

use strict;
use warnings;
use Monitorix;
use RRDs;
use Exporter 'import';
our @EXPORT = qw(int_init int_update int_cgi);

sub int_init {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	my $info;
	my @rra;
	my @tmp;
	my $n;

	my @average;
	my @min;
	my @max;
	my @last;

	if($config->{os} eq "NetBSD") {
		logger("$myself is not supported yet by your operating system ($config->{os}).");
		return;
	}

	if(-e $rrd) {
		$info = RRDs::info($rrd);
		for my $key (keys %$info) {
			if(index($key, 'rra[') == 0) {
				if(index($key, '.rows') != -1) {
					push(@rra, substr($key, 4, index($key, ']') - 4));
				}
			}
		}
		if(scalar(@rra) < 12 + (4 * $config->{max_historic_years})) {
			logger("$myself: Detected size mismatch between 'max_historic_years' (" . $config->{max_historic_years} . ") and $rrd (" . ((scalar(@rra) -12) / 4) . "). Resizing it accordingly. All historical data will be lost. Backup file created.");
			rename($rrd, "$rrd.bak");
		}
	}

	if(!(-e $rrd)) {
		logger("Creating '$rrd' file.");
		for($n = 1; $n <= $config->{max_historic_years}; $n++) {
			push(@average, "RRA:AVERAGE:0.5:1440:" . (365 * $n));
			push(@min, "RRA:MIN:0.5:1440:" . (365 * $n));
			push(@max, "RRA:MAX:0.5:1440:" . (365 * $n));
			push(@last, "RRA:LAST:0.5:1440:" . (365 * $n));
		}
		eval {
			RRDs::create($rrd,
				"--step=60",
				"DS:int_0:COUNTER:120:0:U",
				"DS:int_1:COUNTER:120:0:U",
				"DS:int_2:COUNTER:120:0:U",
				"DS:int_3:COUNTER:120:0:U",
				"DS:int_4:COUNTER:120:0:U",
				"DS:int_5:COUNTER:120:0:U",
				"DS:int_6:COUNTER:120:0:U",
				"DS:int_7:COUNTER:120:0:U",
				"DS:int_8:COUNTER:120:0:U",
				"DS:int_9:COUNTER:120:0:U",
				"DS:int_10:COUNTER:120:0:U",
				"DS:int_11:COUNTER:120:0:U",
				"DS:int_12:COUNTER:120:0:U",
				"DS:int_13:COUNTER:120:0:U",
				"DS:int_14:COUNTER:120:0:U",
				"DS:int_15:COUNTER:120:0:U",
				"DS:int_16:COUNTER:120:0:U",
				"DS:int_17:COUNTER:120:0:U",
				"DS:int_18:COUNTER:120:0:U",
				"DS:int_19:COUNTER:120:0:U",
				"DS:int_20:COUNTER:120:0:U",
				"DS:int_21:COUNTER:120:0:U",
				"DS:int_22:COUNTER:120:0:U",
				"DS:int_23:COUNTER:120:0:U",
				"DS:int_24:COUNTER:120:0:U",
				"DS:int_25:COUNTER:120:0:U",
				"DS:int_26:COUNTER:120:0:U",
				"DS:int_27:COUNTER:120:0:U",
				"DS:int_28:COUNTER:120:0:U",
				"DS:int_29:COUNTER:120:0:U",
				"DS:int_30:COUNTER:120:0:U",
				"DS:int_31:COUNTER:120:0:U",
				"DS:int_32:COUNTER:120:0:U",
				"DS:int_33:COUNTER:120:0:U",
				"DS:int_34:COUNTER:120:0:U",
				"DS:int_35:COUNTER:120:0:U",
				"DS:int_36:COUNTER:120:0:U",
				"DS:int_37:COUNTER:120:0:U",
				"DS:int_38:COUNTER:120:0:U",
				"DS:int_39:COUNTER:120:0:U",
				"DS:int_40:COUNTER:120:0:U",
				"DS:int_41:COUNTER:120:0:U",
				"DS:int_42:COUNTER:120:0:U",
				"DS:int_43:COUNTER:120:0:U",
				"DS:int_44:COUNTER:120:0:U",
				"DS:int_45:COUNTER:120:0:U",
				"DS:int_46:COUNTER:120:0:U",
				"DS:int_47:COUNTER:120:0:U",
				"DS:int_48:COUNTER:120:0:U",
				"DS:int_49:COUNTER:120:0:U",
				"DS:int_50:COUNTER:120:0:U",
				"DS:int_51:COUNTER:120:0:U",
				"DS:int_52:COUNTER:120:0:U",
				"DS:int_53:COUNTER:120:0:U",
				"DS:int_54:COUNTER:120:0:U",
				"DS:int_55:COUNTER:120:0:U",
				"DS:int_56:COUNTER:120:0:U",
				"DS:int_57:COUNTER:120:0:U",
				"DS:int_58:COUNTER:120:0:U",
				"DS:int_59:COUNTER:120:0:U",
				"DS:int_60:COUNTER:120:0:U",
				"DS:int_61:COUNTER:120:0:U",
				"DS:int_62:COUNTER:120:0:U",
				"DS:int_63:COUNTER:120:0:U",
				"DS:int_64:COUNTER:120:0:U",
				"DS:int_65:COUNTER:120:0:U",
				"DS:int_66:COUNTER:120:0:U",
				"DS:int_67:COUNTER:120:0:U",
				"DS:int_68:COUNTER:120:0:U",
				"DS:int_69:COUNTER:120:0:U",
				"DS:int_70:COUNTER:120:0:U",
				"DS:int_71:COUNTER:120:0:U",
				"DS:int_72:COUNTER:120:0:U",
				"DS:int_73:COUNTER:120:0:U",
				"DS:int_74:COUNTER:120:0:U",
				"DS:int_75:COUNTER:120:0:U",
				"DS:int_76:COUNTER:120:0:U",
				"DS:int_77:COUNTER:120:0:U",
				"DS:int_78:COUNTER:120:0:U",
				"DS:int_79:COUNTER:120:0:U",
				"DS:int_80:COUNTER:120:0:U",
				"DS:int_81:COUNTER:120:0:U",
				"DS:int_82:COUNTER:120:0:U",
				"DS:int_83:COUNTER:120:0:U",
				"DS:int_84:COUNTER:120:0:U",
				"DS:int_85:COUNTER:120:0:U",
				"DS:int_86:COUNTER:120:0:U",
				"DS:int_87:COUNTER:120:0:U",
				"DS:int_88:COUNTER:120:0:U",
				"DS:int_89:COUNTER:120:0:U",
				"DS:int_90:COUNTER:120:0:U",
				"DS:int_91:COUNTER:120:0:U",
				"DS:int_92:COUNTER:120:0:U",
				"DS:int_93:COUNTER:120:0:U",
				"DS:int_94:COUNTER:120:0:U",
				"DS:int_95:COUNTER:120:0:U",
				"DS:int_96:COUNTER:120:0:U",
				"DS:int_97:COUNTER:120:0:U",
				"DS:int_98:COUNTER:120:0:U",
				"DS:int_99:COUNTER:120:0:U",
				"DS:int_100:COUNTER:120:0:U",
				"DS:int_101:COUNTER:120:0:U",
				"DS:int_102:COUNTER:120:0:U",
				"DS:int_103:COUNTER:120:0:U",
				"DS:int_104:COUNTER:120:0:U",
				"DS:int_105:COUNTER:120:0:U",
				"DS:int_106:COUNTER:120:0:U",
				"DS:int_107:COUNTER:120:0:U",
				"DS:int_108:COUNTER:120:0:U",
				"DS:int_109:COUNTER:120:0:U",
				"DS:int_110:COUNTER:120:0:U",
				"DS:int_111:COUNTER:120:0:U",
				"DS:int_112:COUNTER:120:0:U",
				"DS:int_113:COUNTER:120:0:U",
				"DS:int_114:COUNTER:120:0:U",
				"DS:int_115:COUNTER:120:0:U",
				"DS:int_116:COUNTER:120:0:U",
				"DS:int_117:COUNTER:120:0:U",
				"DS:int_118:COUNTER:120:0:U",
				"DS:int_119:COUNTER:120:0:U",
				"DS:int_120:COUNTER:120:0:U",
				"DS:int_121:COUNTER:120:0:U",
				"DS:int_122:COUNTER:120:0:U",
				"DS:int_123:COUNTER:120:0:U",
				"DS:int_124:COUNTER:120:0:U",
				"DS:int_125:COUNTER:120:0:U",
				"DS:int_126:COUNTER:120:0:U",
				"DS:int_127:COUNTER:120:0:U",
				"DS:int_128:COUNTER:120:0:U",
				"DS:int_129:COUNTER:120:0:U",
				"DS:int_130:COUNTER:120:0:U",
				"DS:int_131:COUNTER:120:0:U",
				"DS:int_132:COUNTER:120:0:U",
				"DS:int_133:COUNTER:120:0:U",
				"DS:int_134:COUNTER:120:0:U",
				"DS:int_135:COUNTER:120:0:U",
				"DS:int_136:COUNTER:120:0:U",
				"DS:int_137:COUNTER:120:0:U",
				"DS:int_138:COUNTER:120:0:U",
				"DS:int_139:COUNTER:120:0:U",
				"DS:int_140:COUNTER:120:0:U",
				"DS:int_141:COUNTER:120:0:U",
				"DS:int_142:COUNTER:120:0:U",
				"DS:int_143:COUNTER:120:0:U",
				"DS:int_144:COUNTER:120:0:U",
				"DS:int_145:COUNTER:120:0:U",
				"DS:int_146:COUNTER:120:0:U",
				"DS:int_147:COUNTER:120:0:U",
				"DS:int_148:COUNTER:120:0:U",
				"DS:int_149:COUNTER:120:0:U",
				"DS:int_150:COUNTER:120:0:U",
				"DS:int_151:COUNTER:120:0:U",
				"DS:int_152:COUNTER:120:0:U",
				"DS:int_153:COUNTER:120:0:U",
				"DS:int_154:COUNTER:120:0:U",
				"DS:int_155:COUNTER:120:0:U",
				"DS:int_156:COUNTER:120:0:U",
				"DS:int_157:COUNTER:120:0:U",
				"DS:int_158:COUNTER:120:0:U",
				"DS:int_159:COUNTER:120:0:U",
				"DS:int_160:COUNTER:120:0:U",
				"DS:int_161:COUNTER:120:0:U",
				"DS:int_162:COUNTER:120:0:U",
				"DS:int_163:COUNTER:120:0:U",
				"DS:int_164:COUNTER:120:0:U",
				"DS:int_165:COUNTER:120:0:U",
				"DS:int_166:COUNTER:120:0:U",
				"DS:int_167:COUNTER:120:0:U",
				"DS:int_168:COUNTER:120:0:U",
				"DS:int_169:COUNTER:120:0:U",
				"DS:int_170:COUNTER:120:0:U",
				"DS:int_171:COUNTER:120:0:U",
				"DS:int_172:COUNTER:120:0:U",
				"DS:int_173:COUNTER:120:0:U",
				"DS:int_174:COUNTER:120:0:U",
				"DS:int_175:COUNTER:120:0:U",
				"DS:int_176:COUNTER:120:0:U",
				"DS:int_177:COUNTER:120:0:U",
				"DS:int_178:COUNTER:120:0:U",
				"DS:int_179:COUNTER:120:0:U",
				"DS:int_180:COUNTER:120:0:U",
				"DS:int_181:COUNTER:120:0:U",
				"DS:int_182:COUNTER:120:0:U",
				"DS:int_183:COUNTER:120:0:U",
				"DS:int_184:COUNTER:120:0:U",
				"DS:int_185:COUNTER:120:0:U",
				"DS:int_186:COUNTER:120:0:U",
				"DS:int_187:COUNTER:120:0:U",
				"DS:int_188:COUNTER:120:0:U",
				"DS:int_189:COUNTER:120:0:U",
				"DS:int_190:COUNTER:120:0:U",
				"DS:int_191:COUNTER:120:0:U",
				"DS:int_192:COUNTER:120:0:U",
				"DS:int_193:COUNTER:120:0:U",
				"DS:int_194:COUNTER:120:0:U",
				"DS:int_195:COUNTER:120:0:U",
				"DS:int_196:COUNTER:120:0:U",
				"DS:int_197:COUNTER:120:0:U",
				"DS:int_198:COUNTER:120:0:U",
				"DS:int_199:COUNTER:120:0:U",
				"DS:int_200:COUNTER:120:0:U",
				"DS:int_201:COUNTER:120:0:U",
				"DS:int_202:COUNTER:120:0:U",
				"DS:int_203:COUNTER:120:0:U",
				"DS:int_204:COUNTER:120:0:U",
				"DS:int_205:COUNTER:120:0:U",
				"DS:int_206:COUNTER:120:0:U",
				"DS:int_207:COUNTER:120:0:U",
				"DS:int_208:COUNTER:120:0:U",
				"DS:int_209:COUNTER:120:0:U",
				"DS:int_210:COUNTER:120:0:U",
				"DS:int_211:COUNTER:120:0:U",
				"DS:int_212:COUNTER:120:0:U",
				"DS:int_213:COUNTER:120:0:U",
				"DS:int_214:COUNTER:120:0:U",
				"DS:int_215:COUNTER:120:0:U",
				"DS:int_216:COUNTER:120:0:U",
				"DS:int_217:COUNTER:120:0:U",
				"DS:int_218:COUNTER:120:0:U",
				"DS:int_219:COUNTER:120:0:U",
				"DS:int_220:COUNTER:120:0:U",
				"DS:int_221:COUNTER:120:0:U",
				"DS:int_222:COUNTER:120:0:U",
				"DS:int_223:COUNTER:120:0:U",
				"DS:int_224:COUNTER:120:0:U",
				"DS:int_225:COUNTER:120:0:U",
				"DS:int_226:COUNTER:120:0:U",
				"DS:int_227:COUNTER:120:0:U",
				"DS:int_228:COUNTER:120:0:U",
				"DS:int_229:COUNTER:120:0:U",
				"DS:int_230:COUNTER:120:0:U",
				"DS:int_231:COUNTER:120:0:U",
				"DS:int_232:COUNTER:120:0:U",
				"DS:int_233:COUNTER:120:0:U",
				"DS:int_234:COUNTER:120:0:U",
				"DS:int_235:COUNTER:120:0:U",
				"DS:int_236:COUNTER:120:0:U",
				"DS:int_237:COUNTER:120:0:U",
				"DS:int_238:COUNTER:120:0:U",
				"DS:int_239:COUNTER:120:0:U",
				"DS:int_240:COUNTER:120:0:U",
				"DS:int_241:COUNTER:120:0:U",
				"DS:int_242:COUNTER:120:0:U",
				"DS:int_243:COUNTER:120:0:U",
				"DS:int_244:COUNTER:120:0:U",
				"DS:int_245:COUNTER:120:0:U",
				"DS:int_246:COUNTER:120:0:U",
				"DS:int_247:COUNTER:120:0:U",
				"DS:int_248:COUNTER:120:0:U",
				"DS:int_249:COUNTER:120:0:U",
				"DS:int_250:COUNTER:120:0:U",
				"DS:int_251:COUNTER:120:0:U",
				"DS:int_252:COUNTER:120:0:U",
				"DS:int_253:COUNTER:120:0:U",
				"DS:int_254:COUNTER:120:0:U",
				"DS:int_255:COUNTER:120:0:U",
				"RRA:AVERAGE:0.5:1:1440",
				"RRA:AVERAGE:0.5:30:336",
				"RRA:AVERAGE:0.5:60:744",
				@average,
				"RRA:MIN:0.5:1:1440",
				"RRA:MIN:0.5:30:336",
				"RRA:MIN:0.5:60:744",
				@min,
				"RRA:MAX:0.5:1:1440",
				"RRA:MAX:0.5:30:336",
				"RRA:MAX:0.5:60:744",
				@max,
				"RRA:LAST:0.5:1:1440",
				"RRA:LAST:0.5:30:336",
				"RRA:LAST:0.5:60:744",
				@last,
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

	push(@{$config->{func_update}}, $package);
	logger("$myself: Ok") if $debug;
}

sub int_update {
	my $myself = (caller(0))[3];
	my ($package, $config, $debug) = @_;
	my $rrd = $config->{base_lib} . $package . ".rrd";

	my @int;

	my $n;
	my $maxints;
	my $rrdata = "N";

	if($config->{os} eq "Linux") {
		open(IN, "/proc/stat");
		while(<IN>) {
			if(/^intr/) {
				my @tmp = split(' ', $_);
				(undef, undef, @int) = @tmp;
				last;
			}
		}
		close(IN);
	} elsif(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD")) {
		open(IN, "vmstat -i |");
		my $num;
		my $name;
		my $ticks;
		$maxints = 0;
		while(<IN>) {
			if(/^\D{3}(\d+)[\:\/]\s*(\S+)\s*?(\d+)/) {
				$num = $1;
				$name = $2;
				$ticks = $3;
				chomp($ticks);
				$int[$num] += $ticks;
				$maxints = $maxints < $num ? $num : $maxints;
			}
		}
		close(IN);
		for($n = 0; $n < $maxints; $n++) {
			$int[$n] = !$int[$n] ? 0 : $int[$n];
		}
	}

	for($n = 0; $n < scalar(@int); $n++) {
		if(($n % 256) != $n) {
			$int[$n % 256] += $int[$n];
		}
	}

	for($n = 0; $n < 256; $n++) {
		if(!defined($int[$n])) {
			$int[$n] = 0;
		}
		$rrdata .= ":" . $int[$n];
	}

	RRDs::update($rrd, $rrdata);
	logger("$myself: $rrdata") if $debug;
	my $err = RRDs::error;
	logger("ERROR: while updating $rrd: $err") if $err;
}

sub int_cgi {
	my ($package, $config, $cgi) = @_;
	my @output;

	my $int = $config->{int};
	my @rigid = split(',', ($int->{rigid} || ""));
	my @limit = split(',', ($int->{limit} || ""));
	my $tf = $cgi->{tf};
	my $colors = $cgi->{colors};
	my $graph = $cgi->{graph};
	my $silent = $cgi->{silent};
	my $zoom = "--zoom=" . $config->{global_zoom};
	my %rrd = (
		'new' => \&RRDs::graphv,
		'old' => \&RRDs::graph,
	);
	my $version = "new";
	my $pic;
	my $picz;
	my $picz_width;
	my $picz_height;

	my $u = "";
	my $width;
	my $height;
	my @extra;
	my @riglim;
	my @CDEF;
	my @allvalues1;
	my @allvalues2;
	my @allvalues3;
	my @allsigns1;
	my @allsigns2;
	my @allsigns3;
	my $n;
	my $err;

	my @INT;
	my @NAME;
	my @DEF1;
	my @AREA1;
	my @LINE1;
	my @DEF2;
	my @AREA2;
	my @LINE2;
	my @DEF3;
	my @AREA3;
	my @LINE3;
	my $n1;
	my $n2;
	my $n3;
	my @ACOLOR1 =  ("#FFA500",
			"#44EEEE",
			"#CCCCCC",
			"#B4B444",
			"#4444EE",
			"#44EE44",
			"#EEEE44",
			"#444444",
			"#EE44EE",
			"#EE4444",
			"#448844",
			"#BB44EE",
			"#D3D701",
			"#E29136",
			"#DDAE8C",
			"#F29967",
			"#996952",
			"#EB6C75",
			"#B84F6B",
			"#963C74",
			"#A68BBC",
			"#597AB7",
			"#8CB4CE",
			"#63BEE0",
			"#3CB5B0",
			"#7EB97C",
			"#94C36B",
			"#884632",

			"#CD5C5C",
			"#F08080",
			"#FA8072",
			"#E9967A",
			"#FFA07A",
			"#DC143C",
			"#B22222",
			"#8B0000",
			"#FFC0CB",
			"#FF69B4",
			"#FF1493",
			"#C71585",
			"#DB7093",
			"#FFA07A",
			"#FF7F50",
			"#FF6347",
			"#FF4500",
			"#FF8C00",
			"#FFD700",
			"#FFFFE0",
			"#FFFACD",
			"#FFEFD5",
			"#FFE4B5",
			"#FFDAB9",
			"#EEE8AA",
			"#F0E68C",
			"#BDB76B",
			"#E6E6FA",
			"#D8BFD8",
			"#DDA0DD",
			"#EE82EE",
			"#DA70D6",
			"#BA55D3",
			"#9370DB",
			"#9966CC",
			"#8A2BE2",
			"#9400D3",
			"#9932CC",
			"#8B008B",
			"#4B0082",
			"#6A5ACD",
			"#483D8B",
			"#7B68EE",
			"#ADFF2F",
			"#7FFF00",
			"#32CD32",
			"#98FB98",
			"#90EE90",
			"#00FA9A",
			"#00FF7F",
			"#3CB371",
			"#2E8B57",
			"#228B22",
			"#9ACD32",
			"#6B8E23",
			"#808000",
			"#556B2F",
			"#66CDAA",
			"#8FBC8F",
			"#20B2AA",
			"#008B8B",
			"#007070",
			"#E0FFFF",
			"#AFEEEE",
			"#7FFFD4",
			"#40E0D0",
			"#48D1CC",
			"#00CED1",
			"#5F9EA0",
			"#4682B4",
			"#B0C4DE",
			"#B0E0E6",
			"#ADD8E6",
			"#87CEEB",
			"#00BFFF",
			"#1E90FF",
			"#6495ED",
			"#7B68EE",
			"#4169E1",
			"#191970",
			"#FFF8DC",
			"#FFEBCD",
			"#FFDEAD",
			"#F5DEB3",
			"#DEB887",
			"#D2B48C",
			"#BC8F8F",
			"#F4A460",
			"#DAA520",
			"#B8860B",
			"#CD853F",
			"#D2691E",
			"#8B4513",
			"#A0522D",
			"#A52A2A",
			"#800000",
			"#FFFAFA",
			"#F0FFF0",
			"#F0F8FF",
			"#F5F5F5",
			"#FDF5E6",
			"#F5F5DC",
			"#FAEBD7",
			"#FFE4E1",
			"#DCDCDC",
			"#696969",
			"#A9A9A9",
			"#708090",
			"#2F4F4F",
			"#000066",
			"#006633",
			"#660033",
			"#66FFCC",
			"#990066",
			"#996633",
			"#99CCCC",
			"#CC3366",
			"#CC6633",
			"#CC6699",
			"#CC9933",
			"#CC9999",
			"#CCCC33",
			"#CCCC99",
			"#CCFF99",
			"#FF0099",
			"#FF6666",
			"#FF9999",
			"#FFCC99",
			"#FFFF99");

	my @LCOLOR1 =  ("#DDA500",
			"#00EEEE",
			"#888888",
			"#B4B400",
			"#0000EE",
			"#00EE00",
			"#EEEE00",
			"#444444",
			"#EE00EE",
			"#EE0000",
			"#008800",
			"#BB00EE",
			"#C8D200",
			"#DB6612",
			"#CE8248",
			"#EB6A39",
			"#8F4C30",
			"#E20045",
			"#B50C51",
			"#7B0059",
			"#684894",
			"#125AA3",
			"#518FBA",
			"#00AADA",
			"#009790",
			"#359B52",
			"#56AB27",
			"#782F1E",

			"#CD5C5C",
			"#F08080",
			"#FA8072",
			"#E9967A",
			"#FFA07A",
			"#DC143C",
			"#B22222",
			"#8B0000",
			"#FFC0CB",
			"#FF69B4",
			"#FF1493",
			"#C71585",
			"#DB7093",
			"#FFA07A",
			"#FF7F50",
			"#FF6347",
			"#FF4500",
			"#FF8C00",
			"#FFD700",
			"#FFFFE0",
			"#FFFACD",
			"#FFEFD5",
			"#FFE4B5",
			"#FFDAB9",
			"#EEE8AA",
			"#F0E68C",
			"#BDB76B",
			"#E6E6FA",
			"#D8BFD8",
			"#DDA0DD",
			"#EE82EE",
			"#DA70D6",
			"#BA55D3",
			"#9370DB",
			"#9966CC",
			"#8A2BE2",
			"#9400D3",
			"#9932CC",
			"#8B008B",
			"#4B0082",
			"#6A5ACD",
			"#483D8B",
			"#7B68EE",
			"#ADFF2F",
			"#7FFF00",
			"#32CD32",
			"#98FB98",
			"#90EE90",
			"#00FA9A",
			"#00FF7F",
			"#3CB371",
			"#2E8B57",
			"#228B22",
			"#9ACD32",
			"#6B8E23",
			"#808000",
			"#556B2F",
			"#66CDAA",
			"#8FBC8F",
			"#20B2AA",
			"#008B8B",
			"#007070",
			"#E0FFFF",
			"#AFEEEE",
			"#7FFFD4",
			"#40E0D0",
			"#48D1CC",
			"#00CED1",
			"#5F9EA0",
			"#4682B4",
			"#B0C4DE",
			"#B0E0E6",
			"#ADD8E6",
			"#87CEEB",
			"#00BFFF",
			"#1E90FF",
			"#6495ED",
			"#7B68EE",
			"#4169E1",
			"#191970",
			"#FFF8DC",
			"#FFEBCD",
			"#FFDEAD",
			"#F5DEB3",
			"#DEB887",
			"#D2B48C",
			"#BC8F8F",
			"#F4A460",
			"#DAA520",
			"#B8860B",
			"#CD853F",
			"#D2691E",
			"#8B4513",
			"#A0522D",
			"#A52A2A",
			"#800000",
			"#FFFAFA",
			"#F0FFF0",
			"#F0F8FF",
			"#F5F5F5",
			"#FDF5E6",
			"#F5F5DC",
			"#FAEBD7",
			"#FFE4E1",
			"#DCDCDC",
			"#696969",
			"#A9A9A9",
			"#708090",
			"#2F4F4F",
			"#000066",
			"#006633",
			"#660033",
			"#66FFCC",
			"#990066",
			"#996633",
			"#99CCCC",
			"#CC3366",
			"#CC6633",
			"#CC6699",
			"#CC9933",
			"#CC9999",
			"#CCCC33",
			"#CCCC99",
			"#CCFF99",
			"#FF0099",
			"#FF6666",
			"#FF9999",
			"#FFCC99",
			"#FFFF99");

	my @ACOLOR2 =  ("#44EEEE",
			"#4444EE",
			"#44EE44",
			"#EE44EE",
			"#EE4444",
			"#EEEE44");
	my @LCOLOR2 =  ("#00EEEE",
			"#0000EE",
			"#00EE00",
			"#EE00EE",
			"#EE0000",
			"#EEEE00");

	my @ACOLOR3 =  ("#44EE44",
			"#4444EE",
			"#44EEEE",
			"#EE4444",
			"#EE44EE",
			"#EEEE44");
	my @LCOLOR3 =  ("#00EE00",
			"#0000EE",
			"#00EEEE",
			"#EE0000",
			"#EE00EE",
			"#EEEE00");

	$version = "old" if $RRDs::VERSION < 1.3;
	my $rrd = $config->{base_lib} . $package . ".rrd";
	my $title = $config->{graph_title}->{$package};
	my $IMG_DIR = $config->{base_dir} . "/" . $config->{imgs_dir};
	my $imgfmt_uc = uc($config->{image_format});
	my $imgfmt_lc = lc($config->{image_format});
	foreach my $i (split(',', $config->{rrdtool_extra_options} || "")) {
		push(@extra, trim($i)) if trim($i);
	}

	$title = !$silent ? $title : "";

	if($config->{os} eq "Linux") {
		open(IN, "/proc/interrupts");
		my $timer_pos = 0;
		my $i8042_pos = 0;
		my $good_pos = 0;
		my $num;
		my $name;
		while(<IN>) {
			if(/Dynamic-irq/) {
				next;
			}
			if(/[0-9]:/) {
				# Assuming int 0 will be only for timer
				if(/\s+0:/ || /^256:/) {
					$timer_pos = index($_, "timer", 0);
				}
				# Assuming int 1 will be only for i8042
				if(/\s+1:/) {
					$i8042_pos = index($_, "i8042", 0);
				}
				# Assuming int 3 will be only for "BCM2708 Timer Tick" (on Raspberry Pi)
				if(/\s+3:/ && !$timer_pos) {
					$timer_pos = index($_, "BCM2708 Timer Tick", 0);
				}

				# Assuming int 1 will be only for "orion_tick" (on Excito B3)
				if(/\s+1:/ && !$timer_pos) {
					$timer_pos = index($_, "orion_tick", 0);
				}
				$timer_pos = $timer_pos == 0 ? 999 : $timer_pos;
				$i8042_pos = $i8042_pos == -1 ? 0 : $i8042_pos;
				$good_pos = $timer_pos > $i8042_pos ? $i8042_pos : $timer_pos;
				$good_pos = $good_pos ? $good_pos : $timer_pos;
				$num = unpack("A4", $_);
				$name = "";
				if(length($_) >= $good_pos) {
					$name = substr($_, $good_pos);
					$name = defined($name) ? $name : "";
				}
				chomp($num, $name);
				$name =~ s/^\s+//;
				$num =~ s/^\s+//;
				$num =~ s/:.*//;
				$n = $num;
				$num = $num > 255 ? $num % 256 : $num;
				$INT[$num] = defined($INT[$num]) ? $INT[$num] . "," : "";
				$NAME[$num] = defined($NAME[$num]) ? $NAME[$num] . ", " : "";
				$INT[$num] .= $n;
				$NAME[$num] .= $name;
			}
		}
		close(IN);
	} elsif(grep {$_ eq $config->{os}} ("FreeBSD", "OpenBSD")) {
		open(IN, "vmstat -i | sort |");
		my $num;
		my $name;
		while(<IN>) {
			if(/^\D{3}(\d+)[\:\/]\s*(\S+)\s*?(\d+)/) {
				$num = $1;
				$name = $2;
				# only the first timer (cpu0) is covered
				if($name eq "timer") {
					if($num != 0) {
						next;
					}
				}

				$n = $num;
				$num = $num > 255 ? $num % 256 : $num;
				$INT[$num] = defined($INT[$num]) ? $INT[$num] . "," : "";
				$NAME[$num] = defined($NAME[$num]) ? $NAME[$num] . ", " : "";
				$INT[$num] .= $n;
				$NAME[$num] .= $name;
			}
		}
		close(IN);

		chomp(@NAME);
		# strip all blank spaces at the end of the strings
		for($n = 0; $n < 256; $n++) {
			if(defined($NAME[$n])) {
				$NAME[$n] =~ s/\s+$//;
			}
		}
	}


	# text mode
	#
	if(lc($config->{iface_mode}) eq "text") {
		if($title) {
			push(@output, main::graph_header($title, 2));
			push(@output, "    <tr>\n");
			push(@output, "    <td>\n");
		}
		my (undef, undef, undef, $data) = RRDs::fetch("$rrd",
			"--resolution=$tf->{res}",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"AVERAGE");
		$err = RRDs::error;
		push(@output, "ERROR: while fetching $rrd: $err\n") if $err;
		my $line1;
		push(@output, "    <pre style='font-size: 12px; color: $colors->{fg_color}';>\n");
		push(@output, "Time   ");
		for($n = 0; $n < 256; $n++) {
			if(defined($INT[$n])) {
				push(@output, sprintf(" %8s", $INT[$n]));
				$line1 .= "---------";
			}
		}
		push(@output, " \n");
		push(@output, "-------$line1\n");
		my $line;
		my @row;
		my $time;
		for($n = 0, $time = $tf->{tb}; $n < ($tf->{tb} * $tf->{ts}); $n++) {
			$line = @$data[$n];
			@row = @$line;
			$time = $time - (1 / $tf->{ts});
			push(@output, sprintf(" %2d$tf->{tc}   ", $time));
			for($n2 = 0; $n2 < 256; $n2++) {
				if(defined($INT[$n2])) {
					push(@output, sprintf(" %8d", $row[$n2]));
				}
			}
			push(@output, " \n");
		}
		push(@output, "    </pre>\n");
		if($title) {
			push(@output, "    </td>\n");
			push(@output, "    </tr>\n");
			push(@output, main::graph_footer());
		}
		push(@output, "  <br>\n");
		return @output;
	}


	# graph mode
	#
	if($silent eq "yes" || $silent eq "imagetag") {
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "_";
	}
	if($silent eq "imagetagbig") {
		$colors->{fg_color} = "#000000";  # visible color for text mode
		$u = "";
	}

	my $IMG1 = $u . $package . "1." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2 = $u . $package . "2." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3 = $u . $package . "3." . $tf->{when} . ".$imgfmt_lc";
	my $IMG1z = $u . $package . "1z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG2z = $u . $package . "2z." . $tf->{when} . ".$imgfmt_lc";
	my $IMG3z = $u . $package . "3z." . $tf->{when} . ".$imgfmt_lc";
	unlink ("$IMG_DIR" . "$IMG1",
		"$IMG_DIR" . "$IMG2",
		"$IMG_DIR" . "$IMG3");
	if(lc($config->{enable_zoom}) eq "y") {
		unlink ("$IMG_DIR" . "$IMG1z",
			"$IMG_DIR" . "$IMG2z",
			"$IMG_DIR" . "$IMG3z");
	}

	if($title) {
		push(@output, main::graph_header($title, 2));
	}
	@riglim = @{setup_riglim($rigid[0], $limit[0])};
	if($title) {
		push(@output, "    <tr>\n");
		push(@output, "    <td>\n");
	}
	my $i;
	for($n = 0, $n1 = 0, $n2 = 0, $n3 = 0; $n < 256; $n++) {
		if(defined($NAME[$n])) {
			# We need to escape colons to support RRDtool v1.2+
			if($RRDs::VERSION > 1.2) {
				$NAME[$n] =~ s/:/\\:/g;
			}
		}
		if(defined($INT[$n])) {
			if(index($INT[$n], ",", 0) < 0) {
				$i = $INT[$n];
			} else {
				($i) = split(',', $INT[$n]);
			}
			if($i < 3 || $NAME[$n] =~ /timer/i) {
				push(@DEF2, ("DEF:int" . $n . "=" . $rrd . ":int_" . $n . ":AVERAGE"));
				push(@AREA2, ("AREA:int" . $n . $ACOLOR2[$n2] . ":(" . $INT[$n] . ")" . $NAME[$n]));
				push(@LINE2, ("LINE1:int" . $n . $LCOLOR2[$n2]));
				push(@allvalues2, "int$n");
				push(@allsigns2, "+");
				$n2++;
			} elsif($i < 6 || $NAME[$n] =~ /^xen/) {
				push(@DEF3, ("DEF:int" . $n . "=" . $rrd . ":int_" . $n . ":AVERAGE"));
				push(@AREA3, ("AREA:int" . $n . $ACOLOR3[$n3] . ":(" . $INT[$n] . ")" . $NAME[$n]));
				push(@LINE3, ("LINE1:int" . $n . $LCOLOR3[$n3]));
				push(@allvalues3, "int$n");
				push(@allsigns3, "+");
				$n3++;
			} else {
				push(@DEF1, ("DEF:int" . $n . "=" . $rrd . ":int_" . $n . ":AVERAGE"));
				push(@AREA1, ("AREA:int" . $n . $ACOLOR1[$n1] . ":(" . $INT[$n] . ")" . $NAME[$n]));
				push(@LINE1, ("LINE1:int" . $n . $LCOLOR1[$n1]));
				push(@allvalues1, "int$n");
				push(@allsigns1, "+");
				$n1++;
				if(!($n1 % 3)) {
					push(@AREA1, ("COMMENT: \\n"));
				}
			}
		}
	}
	push(@AREA1, ("COMMENT: \\n"));
	pop(@allsigns1);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues1, @allsigns1))
		if(scalar(@allvalues1));
	if(lc($config->{show_gaps}) eq "y") {
		push(@AREA1, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{main});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG1",
		"--title=$config->{graphs}->{_int1}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Ticks/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$colors->{graph_colors}},
		@DEF1,
		@CDEF,
		@AREA1,
		@LINE1);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG1z",
			"--title=$config->{graphs}->{_int1}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Ticks/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$colors->{graph_colors}},
			@DEF1,
			@CDEF,
			@AREA1,
			@LINE1);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG1z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /int1/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG1 . "'>\n");
		}
	}

	if($title) {
		push(@output, "    </td>\n");
		push(@output, "    <td class='td-valign-top'>\n");
	}

	@riglim = @{setup_riglim($rigid[1], $limit[1])};
	undef(@CDEF);
	pop(@allsigns2);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues2, @allsigns2))
		if(scalar(@allvalues2));
	if(lc($config->{show_gaps}) eq "y") {
		push(@AREA2, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
	}
	$pic = $rrd{$version}->("$IMG_DIR" . "$IMG2",
		"--title=$config->{graphs}->{_int2}  ($tf->{nwhen}$tf->{twhen})",
		"--start=-$tf->{nwhen}$tf->{twhen}",
		"--imgformat=$imgfmt_uc",
		"--vertical-label=Ticks/s",
		"--width=$width",
		"--height=$height",
		@extra,
		@riglim,
		$zoom,
		@{$cgi->{version12}},
		@{$cgi->{version12_small}},
		@{$colors->{graph_colors}},
		@DEF2,
		@CDEF,
		@AREA2,
		@LINE2);
	$err = RRDs::error;
	push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2: $err\n") if $err;
	if(lc($config->{enable_zoom}) eq "y") {
		($width, $height) = split('x', $config->{graph_size}->{zoom});
		$picz = $rrd{$version}->("$IMG_DIR" . "$IMG2z",
			"--title=$config->{graphs}->{_int2}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Ticks/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			@DEF2,
			@CDEF,
			@AREA2,
			@LINE2);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG2z: $err\n") if $err;
	}
	if($title || ($silent =~ /imagetag/ && $graph =~ /int2/)) {
		if(lc($config->{enable_zoom}) eq "y") {
			if(lc($config->{disable_javascript_void}) eq "y") {
				push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			} else {
				if($version eq "new") {
					$picz_width = $picz->{image_width} * $config->{global_zoom};
					$picz_height = $picz->{image_height} * $config->{global_zoom};
				} else {
					$picz_width = $width + 115;
					$picz_height = $height + 100;
				}
				push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "' border='0'></a>\n");
			}
		} else {
			push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG2 . "'>\n");
		}
	}

	@riglim = @{setup_riglim($rigid[2], $limit[2])};
	undef(@CDEF);
	pop(@allsigns3);
	push(@CDEF, "CDEF:allvalues=" . join(',', @allvalues3, @allsigns3))
		if(scalar(@allvalues3));
	if(lc($config->{show_gaps}) eq "y") {
		push(@AREA3, "AREA:wrongdata#$colors->{gap}:");
		push(@CDEF, "CDEF:wrongdata=allvalues,UN,INF,UNKN,IF");
	}
	($width, $height) = split('x', $config->{graph_size}->{small});
	if($silent =~ /imagetag/) {
		($width, $height) = split('x', $config->{graph_size}->{remote}) if $silent eq "imagetag";
		($width, $height) = split('x', $config->{graph_size}->{main}) if $silent eq "imagetagbig";
	}
	if(@DEF3 && @AREA3 && @LINE3) {
		$pic = $rrd{$version}->("$IMG_DIR" . "$IMG3",
			"--title=$config->{graphs}->{_int3}  ($tf->{nwhen}$tf->{twhen})",
			"--start=-$tf->{nwhen}$tf->{twhen}",
			"--imgformat=$imgfmt_uc",
			"--vertical-label=Ticks/s",
			"--width=$width",
			"--height=$height",
			@extra,
			@riglim,
			$zoom,
			@{$cgi->{version12}},
			@{$cgi->{version12_small}},
			@{$colors->{graph_colors}},
			@DEF3,
			@CDEF,
			@AREA3,
			@LINE3);
		$err = RRDs::error;
		push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3: $err\n") if $err;
		if(lc($config->{enable_zoom}) eq "y") {
			($width, $height) = split('x', $config->{graph_size}->{zoom});
			$picz = $rrd{$version}->("$IMG_DIR" . "$IMG3z",
				"--title=$config->{graphs}->{_int3}  ($tf->{nwhen}$tf->{twhen})",
				"--start=-$tf->{nwhen}$tf->{twhen}",
				"--imgformat=$imgfmt_uc",
				"--vertical-label=Ticks/s",
				"--width=$width",
				"--height=$height",
				@extra,
				@riglim,
				$zoom,
				@{$cgi->{version12}},
				@{$cgi->{version12_small}},
				@{$colors->{graph_colors}},
				@DEF3,
				@CDEF,
				@AREA3,
				@LINE3);
			$err = RRDs::error;
			push(@output, "ERROR: while graphing $IMG_DIR" . "$IMG3z: $err\n") if $err;
		}
		if($title || ($silent =~ /imagetag/ && $graph =~ /int3/)) {
			if(lc($config->{enable_zoom}) eq "y") {
				if(lc($config->{disable_javascript_void}) eq "y") {
					push(@output, "      <a href=\"" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
				} else {
					if($version eq "new") {
						$picz_width = $picz->{image_width} * $config->{global_zoom};
						$picz_height = $picz->{image_height} * $config->{global_zoom};
					} else {
						$picz_width = $width + 115;
						$picz_height = $height + 100;
					}
					push(@output, "      <a href=\"javascript:void(window.open('" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3z . "','','width=" . $picz_width . ",height=" . $picz_height . ",scrollbars=0,resizable=0'))\"><img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "' border='0'></a>\n");
				}
			} else {
				push(@output, "      <img src='" . $config->{url} . "/" . $config->{imgs_dir} . $IMG3 . "'>\n");
			}
		}
	}
	if($title) {
		push(@output, "    </td>\n");
		push(@output, "    </tr>\n");
		push(@output, main::graph_footer());
	}
	push(@output, "  <br>\n");
	return @output;
}

1;
