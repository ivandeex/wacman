#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use strict;
use warnings;
use utf8;
use Carp qw(cluck croak);
use Getopt::Std;
use Gtk2 -init;
use POSIX;
use Encode;
use Time::HiRes 'gettimeofday';
use Net::LDAP;
use Net::LDAP::Entry;
use File::Find;
use File::Copy::Recursive;

use FindBin qw[$Bin];
use Cwd 'abs_path';

my ($uni, $ads, $pname, $main_wnd, %install);

my ($btn_usr_apply, $btn_usr_revert, $btn_usr_add, $btn_usr_delete, $btn_usr_refresh);
my ($user_list, $user_attr_frame, $user_attr_tabs, $user_name);
my $user_obj = {};

my ($btn_grp_apply, $btn_grp_revert, $btn_grp_add, $btn_grp_delete, $btn_grp_refresh);
my ($group_list, $group_attr_frame, $group_name);
my $group_obj = {};

my ($next_uidn, $next_gidn);

my $pic_home = abs_path("$Bin/images");
my %pic_cache;

my %translations;

my %ldap_rw_subs;

sub _T	{
	my ($fmt, @args) = @_;
	return sprintf(defined($translations{$fmt}) ? $translations{$fmt} : $fmt, @args);
}


# ======== config =========


use constant NO_EXPIRE => '9223372036854775807';
use constant SAM_USER_OBJECT => hex('0x30000000');
use constant ADS_UF_NORMAL_ACCOUNT => hex(0x00000200);


my @servers = [ 'uni', 'ads' ];

my %servers = (
	ads => {
		uri		=>	'ldaps://xxx.winsrv.vpn',
		user	=>	'cn=dirman,dc=gclimate,dc=local',
		passfile=>	'/etc/userman.secret',
		base	=>	'dc=gclimate,dc=local',
		debug	=>	0,
		convert	=>	0,
		disable =>	0,
	},
	uni => {
		uri		=>	'ldaps://xxx.el4.vihens.ru',
		user	=>	'cn=dirman,dc=vihens,dc=ru',
		passfile=>	'/etc/userman.secret',
		base	=>	'dc=vihens,dc=ru',
		debug	=>	0,
		convert	=>	1,
		disable =>	0,
	}
);


%translations = (
	'Domain Users'	=>	'Пользователи домена',
	'Remote Users'	=>	'Пользователи удаленного рабочего стола',
	'Name'			=>	'Имя',
	'Second name'	=>	'Фамилия',
	'Full name'		=>	'Полное имя',
	'Identifier'	=>	'Идентификатор',
	'Mail'			=>	'Почта',
	'User#'			=>	'# Пользователя',
	'Group'			=>	'Группа',
	'Other groups'	=>	'Прочие группы',
	'Home directory'=>	'Домашний каталог',
	'Login shell'	=>	'Интерпретатор команд',
	'Drive'			=>	'Диск',
	'Profile'		=>	'Профиль',
	'Logon script'	=>	'Сценарий входа',
	'Telephone'		=>	'Телефон',
	'Fax number'	=>	'Номер факса',
	'Extended'		=>	'Дополнительно',
	'User "%s" not found'	=>	'Не найден пользователь "%s"',
	'User "%s" not found: %s'	=>	'Пользователь "%s" не найден: %s',
	'Error reading list of Windows groups: %s'	=>	'Ошибка чтения списка Windows-групп: %s',
	'Error reading Windows group "%s" (%s): %s'	=>	'Ошибка чтения Windows-группы "%s" (%s): %s',
	'Error updating Windows-user "%s": %s'	=>	'Ошибка обновления Windows-пользьвателя "%s": %s',
	'Error re-updating Unix-user "%s" (%s): %s'	=>	'Ошибка пере-обновления Unix-пользьвателя "%s" (%s): %s',
	'Error adding "%s" to Windows-group "%s": %s'	=>	'Ошибка добавления "%s" в Windows-группу "%s": %s',
	'Error saving user "%s" (%s): %s'	=>	'Ошибка сохранения пользователя "%s" (%s): %s',
	'Really revert changes ?'	=>	'Действительно откатить модификации ?',
	'Delete user "%s" ?'	=>	'Удалить пользователя "%s" ?',
	'Cancel new user ?'		=>	'Отменить добавление пользователя ?',
	'Error deleting Unix-user "%s" (%s): %s'	=>	'Ошибка удаления Unix-пользователя "%s" (%s): %s',
	'Error deleting Windows-user "%s": %s'	=>	'Ошибка удаления Windows-пользователя "%s": %s',
	'Cannot display user "%s"'	=>	'Не могу вывести пользователя "%s"',
	'Exit and loose changes ?'	=>	'Выйти и потерять изменения ?',
	'Attributes'	=>	'Атрибуты',
	'Save'	=>	'Сохранить',
	'Revert'	=>	'Отменить',
	'Identifier'	=>	'Идентификатор',
	'Full name'	=>	'Полное имя',
	'Create'	=>	'Добавить',
	'Delete'	=>	'Удалить',
	'Refresh'	=>	'Обновить',
	'Exit'	=>	'Выйти',
	'Close'	=>	'Закрыть',
	' Users '	=>	' Пользователи ',
	' Groups '	=>	' Группы ',
	'Group name'	=>	'Название группы',
	'Group number'	=>	'Номер группы',
	'Description'	=>	'Описание',
	'Members'		=>	'Члены группы',
	'Error saving group "%s": %s'	=>	'Ошибка сохранения группы "%s": %s',
	'Cancel new group ?'	=>	'Отменить добавление группы ?',
	'Delete group "%s" ?'	=>	'Удалить группу "%s"',
	'Error deleting group "%s": %s'	=> 'Ошибка удаления группы "%s": %s',
	'Cannot display group "%s"'	=>	'Не могу отобразить группу "%s"',
	'Groups not found: %s' => 'Группы не найдены: %s',
);


my %config = (
	debug				=>	0,
	nodirs				=>	0,
	ntuser_support		=>	0,
	config_files		=>	[
			'/etc/userman.conf',
			'~/.userman.conf',
			'./userman.conf'
		],
	skel_dir			=>	'/etc/skel',
	unix_user_dn		=>	'uid=[uid],ou=People,dc=vihens,dc=ru',
	unix_group_dn		=>	'cn=[cn],ou=Groups,dc=vihens,dc=ru',

	unix_user_classes	=>	'top,person,organizationalPerson,inetOrgPerson,posixAccount,shadowAccount',
							# 'ntUser',
	unix_group_classes	=>	'top,posixGroup',	
	ad_user_classes		=>	'top,user,person,organizationalPerson',	
	ad_user_category	=>	'Person.Schema.Configuration',

	ad_initial_pass		=>	'123qweASD',
	ad_primary_group	=>	_T('Domain Users'),
	ad_user_groups		=>	[ _T('Remote Users') ],
	ad_user_container	=>	'Users',

	unix_gids			=>	[ 100 ],
	unix_domain			=>	'gclimate.com',
	ad_domain			=>	'gclimate.local',
	home_server			=>	'el.vpn',
	home_drive			=>	'H',
	ad_home_dir			=>	'//[SERVER]/[USER]$/Home',
	ad_script_path		=>	'//[SERVER]/[USER]$/Netlogon/logon.cmd',
	ad_profile_path		=>	'//[SERVER]/[USER]$/Profile',
);


my %all_attrs = (
	########## user ##########
	user => {
		objectClass => {
			type => 'c',
			ldap => { uni => 'objectClass' },
		},
		ntObjectClass => {
			type => 'c',
			ldap => { 'ads' => 'objectClass' },
		},
		# posixAccount...
		givenName => {
			label => 'Name',
			ldap => 'uni,ads',
		},
		sn => {
			label => 'Second name',
			ldap => 'uni,ads',
		},
		cn => {
			label => 'Full name',
			ldap => { uni => '', ads => 'displayName', },
		},
		uid => {
			type => 'd',
			label => 'Identifier',
			ldap => 'uni,ads',
		},
		mail => {
			label => 'Mail',
			ldap => 'uni,ads',
		},
		uidNumber => {
			label => 'User#',
			ldap => 'uni,ads',
		},
		gidNumber => {
			type => 'g',
			label => 'Group',
			ldap => 'uni,ads',
			default => 100,
		},
		moreGroups => {
			type => 'G',
			label => 'Other groups',
			ldap => { uni => 'uidNumber' },
		},
		homeDirectory => {
			label => 'Home directory',
			ldap =>  { uni => '', ads => 'unixHomeDirectory' },
		},
		loginShell => {
			label => 'Login shell',
			ldap => 'uni,ads',
			default => '/bin/bash', 
		},
		# Active Directory...
		accountExpires => {
			default => NO_EXPIRE,
			ldap => 'ads',
			conv => 'adtime',
		},
		sAMAccountName => {
			ldap => 'ads',
			copyfrom => 'uid',
		},
		unixUserPassword => {
			type => 'p',
			ldap => 'ads',
			copyfrom => 'userPassword',
			disable => 1,
		},
		instanceType => {
			default => '4',
			ldap => 'ads',
		},
		userAccountControl=> {
			conv => 'decihex',
			default => 512,		# FIXME! ADS_UF_NORMAL_ACCOUNT
		},
		userPrincipalName => {
			ldap => 'ads',
		},
		ntUserHomeDir => {
			label => 'Home directory',
			ldap => { ntuser => '', ads => 'homeDirectory' },
		},
		ntUserHomeDirDrive => {
			label => 'Drive',
			default => 'H',
			ldap => { ntuser => '', ads => 'homeDrive' },
		},
		ntUserProfile => {
			label => 'Profile',
			ldap => { ntuser => '', ads => 'profilePath' },
		},
		ntUserScriptPath => {
			label => 'Logon script',
			ldap => { ntuser => '', ads => 'scriptPath' },
		},
		PrimaryGroupID => {
			type => 'a',
			ldap => 'ads',
		},
		SecondaryGroups => {
			type => 'A',
			ldap => 'ads',
		},
		# ntUser...
		ntUserCreateNewAccount => {
			default => 'false',
			ldap => 'ntuser',
		},
		ntUserDeleteAccount => {
			default => 'false',
			ldap => 'ntuser',
		},
		ntUserAcctExpires => {
			default => NO_EXPIRE,
			conv => 'adtime',
			ldap => 'ntuser',
		},
		ntUserLastLogon	=> {
			conv => 'adtime',
		},
		# Active Directory disabled...
		ufn			=> { conv => 'bkslash', },
		objectSid	=> { conv => 'binary', },
		objectGuid	=> { conv => 'binary', },
		systemFlags	=> { conv => 'decihex', },
		groupType	=> { conv => 'decihex', },
		whenCreated	=> { conv => 'monotime', },
		whenChanged	=> { conv => 'monotime', },
		pwdLastSet	=> { conv => 'adtime', },
		badPasswordTime	=> { conv => 'adtime', },
		lastLogon	=> { conv => 'adtime', },
		lastLogoff	=> { conv => 'adtime', },
		logonHours	=> { conv => 'binary', },
		userParameters	=> { conv => 'binary', },
		codePage => { default => pack('c',0), },
		countryCode => { default => '0', },
		logonCount => { default => '0', },
		pwdLastSet => { default => '0', },
		samAccountType => {
			default => SAM_USER_OBJECT,
			conv => 'decihex',
			disable => 1,
		},
		# personal / extended...
		telephoneNumber => {
			label => 'Telephone',
			ldap => 'uni,ads',
			#default => '',
		},
		facsimileTelephoneNumber => {
			label => 'Fax number',
			ldap => 'uni,ads',
			#default => '',
		},
		physicalDeliveryOfficeName => {
			ldap => 'uni,ads',
			#default => '',
		},
		o => { ldap => 'uni,ads', },
		ou => { ldap => 'uni,ads', },
		label => { ldap => 'uni,ads', },
	},
	########## group ##########
	group => {
		cn => {
			label => 'Group name',
			ldap => 'uni',
		},
		gidNumber => {
			label => 'Group number',
			ldap => 'uni',
		},
		description => {
			label => 'Description',
			ldap => 'uni',
		},
		memberUid => {
			type => 'U',
			label => 'Members',
			ldap => 'uni',
		},
	},
);


my %all_lc_attrs;


my %gui_attrs = (
	user => [
		[ 'UNIX', qw(givenName sn cn uid mail uidNumber gidNumber moreGroups homeDirectory loginShell) ],
		[ 'Windows', qw(ntUserHomeDir ntUserHomeDirDrive ntUserProfile ntUserScriptPath) ],
		[ 'Communigate', ],
		[ 'Extended', qw(telephoneNumber facsimileTelephoneNumber) ],
	],
	group => [
		[ 'UNIX', qw(cn gidNumber description memberUid) ],
	],
);


my %state2has = (
	force => 0,
	user => 1,
	empty => 0,
	orig => 1,
	calc => 0,
);


my %state2pic = (
	'user'  => 'yellow.png',
	'orig'  => 'green.png',
	'calc'  => 'blue.png',
	'empty' => 'empty.png',
);

my @toggle_icon = ('', 'blue.png');

my %convtype2subs;


# ======== configuring ========


sub configure
{
	for my $file (@_) {
		next unless $file;
		$file =~ s/^~\//$ENV{HOME}\//;
		next unless -r $file;
		open(CONFIG, "$file") or next;
		my $mode = "config";
		my %modes = ( ads => 1, uni => 1, config => 1 );
		while (<CONFIG>) {
			chop;
			chomp;
			next if /^\s*$/;
			next if /^\s*\#/;
			if (/^\s*\[\s*(\S+)\s*\]\s*$/) {
				$mode = $1;
				log_error('incorrect section "%s" in %s: %s', $mode, $file, $_)
					unless $modes{$mode};
				next;
			} elsif (/^\s*(\S+)\s*=\s*(.*?)\s*$/) {
				my ($name, $val) = ($1, $2);
				if ($val =~ /^\'(.*?)\'$/) {
					$val = $1;
				} elsif ($val =~ /^\"(.*?)\"$/) {
					$val = $1;
				} elsif ($val =~ /^\[\s*(.*?)\s*\]$/) {
					my @val = split(/\s*,\s*/,$1);
					@val = map {
						if (/^\'(.*?)\'$/) { $1; }
						elsif (/^\"(.*?)\"$/) { $1; }
						else { $_; }
					} @val;
					$val = \@val;
				}
				if ($mode eq 'ads' || $mode eq 'uni') {
					$servers{$mode}{$name} = $val;
				} elsif ($mode eq "config") {
					$config{$name} = $val;				
				}
			} else {
				log_error('incorrect line in %s: %s', $file, $_);
			}
		}
		close(CONFIG);
	}
}


sub dump_config
{
	for (sort keys %{$servers{uni}}) { print "uni{$_} = \"$servers{uni}->{$_}\"\n"; }
	for (sort keys %{$servers{ads}}) { print "ads{$_} = \"$servers{ads}->{$_}\"\n"; }
	for (sort keys %config) {
		my $val = $config{$_};
		$val = ($val =~ /^ARRAY\(\S+\)$/)
					? '[ '.join(', ',map("\"$_\"",@$val)).' ]' : "\"$val\"";
		print "config{$_} = $val\n";
	}
}


sub setup_attrs
{
	for my $objtype ('user', 'group') {
		for my $srv (keys %servers) {
			$servers{$srv}{attrhash}{$objtype} = {};
		}
		$all_lc_attrs{$objtype} = {};
		my $descs = $all_attrs{$objtype};

		for my $name (keys %$descs) {
			my $at = $descs->{$name};
			$all_lc_attrs{$objtype}->{lc($name)} = $at;
			$at->{name} = $name;

			my $subs = $ldap_rw_subs{$at->{type}};
			log_error('type "%s" of "%s" attribute "%s" is not supported',
						$at->{type}, $objtype, $name) unless $subs;
			$at->{ldap_read} = $subs->[0];
			$at->{ldap_write} = $subs->[1];
			$at->{ldap_write_final} = $subs->[2];

			$at->{conv} = 'none' unless $at->{conv};
			for my $dir (0, 1) {
				my $sub;
				$sub = $convtype2subs{$at->{conv}}->[$dir]
					if defined $convtype2subs{$at->{conv}};
				$sub = \&conv_none unless $sub;
				$at->{$dir ? 'disp2attr' : 'attr2disp'} = $sub;
			}

			$at->{visual} = $at->{label} ? 1 : 0;
			$at->{label} = _T($at->{label}) if $at->{label};

			$at->{disable} = 1 unless $at->{ldap};
			if ($at->{ldap}) {
				$at->{disable} = 0 unless $at->{disable};
				unless (ref $at->{ldap}) {
					my @list = split_list $at->{ldap};
					$at->{ldap} = {};
					for (@list) { $at->{ldap}->{$_} = '' }
				}
				log_error('incorrect ldap definition in attribute "%s"', $name)
					if ref($at->{ldap}) ne 'HASH';
				my $ldap = $at->{ldap};
				for my $srv (keys %$ldap) {
					# 'ntuser' is a special set of unix attributes
					# they can be either supported as 'uni' or unsupported
					if ($srv eq 'ntuser') {
						if ($config{ntuser_support}) {
							$ldap->{$srv = 'uni'} = $ldap->{ntuser};
							delete $ldap->{ntuser};
						} else {
							delete $ldap->{ntuser};
							next;
						}
					}
					$ldap->{$srv} = $name unless $ldap->{$srv};
					my $ssattr = $ldap->{$srv};
					log_error('attribute "%s" bound to unknown server "%s"', $name, $srv)
						unless $servers{$srv};
					log_error('duplicate attribute "%s" for server "%s"', $name, $srv)
						if $servers{$srv}{attrhash}{$ssattr};
					$servers{$srv}{attrhash}{$ssattr} = 1;
				}
				$at->{disable} = 1 if scalar(keys %$ldap) == 0;
			}
		}
		for my $srv (keys %servers) {
			my @attr_list = sort keys %{$servers{$srv}{attrhash}{$objtype}};
			$servers{$srv}{attrlist}{$objtype} = \@attr_list;
		}
	}
}


# ======= Visualization =========


use constant SECS1610TO1970 => 11644473600;
my $HR = "=" x 48;

%convtype2subs = (
	'none' => [
		\&conv_none,
		\&conv_none,
	],
	'bkslash'	=> [
		sub { $_=$_[0];
			  s/\\([8-9A-F][0-9A-F])/chr(hex($1))/eg;
			  $_; },
		sub { $_=$_[0];
			  s/([\x{80}-\x{FF}])/sprintf("\\%02X",ord($1))/eg;
			  $_; }
	],
	'binary' 	=> [
		sub { $_=$_[0];
			  s/([\x{00}-\x{FF}])/sprintf("%02x,",ord($1))/eg;
			  $_; },
		sub { $_=$_[0];
			  s/([0-9a-f]{1,2}),/chr(hex($1))/eg;
			  $_; }
	],
	'monotime'	=> [
		sub { $_=$_[0];
			  s/^(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\.0Z$/$1-$2-$3;$4:$5:$6.000000;0/;
			  $_;
		},
		sub { $_=$_[0];
			  s/^(\d{4})-(\d\d)-(\d\d);(\d\d):(\d\d):(\d\d)\.000000\;0$/$1$2$3$4$5$6.0Z/;
		      $_;
		}
	],
	'decihex'	=> [
		sub {
			sprintf("0x%04x",$_[0]);
		},
		sub {
			$_ = hex($_[0]);
			if ($_ >= 0x80000000) {
				$_ = -1 - ~$_;
			}
			$_;
		}
	],
	'adtime'	=> [
		sub {
			$_ = $_[0];
			if ($_ eq NO_EXPIRE) {
				-1;
			} elsif ($_ == 0) {
				0;
			} else {
				my $ns100ep = $_[0];
				$ns100ep =~ /(\d{6})\d$/; # FIXME: no math since rounding problems !
				my $us = $1;
				my $windsec = POSIX::floor(($ns100ep - $us * 10) / 1e+7 + 0.5);
				my $unixsec = $windsec - SECS1610TO1970; 
				my ($s,$mi,$h,$d,$mo,$y,$wd,$yd,$dst) = localtime($unixsec);
				my $ret = sprintf("%04d-%02d-%02d;%02d:%02d:%02d.%06d;%d",
								$y+1900,$mo+1,$d,$h,$mi,$s,$us,$dst);
				$ret;
			}
		},
		sub {
			$_ = $_[0];
			if ($_ == -1) {
				NO_EXPIRE;
			} elsif ($_ =~ /^(\d{4})-(\d\d)-(\d\d);(\d\d):(\d\d):(\d\d)\.(\d{6});(\d)$/) {
				my ($y,$mo,$d,$h,$mi,$s,$us,$dst) = ($1,$2,$3,$4,$5,$6,$7,$8);
				my $unixsec = POSIX::mktime($s,$mi,$h,$d,$mo-1,$y-1900,0,0,$dst);
				my $windsec = $unixsec + SECS1610TO1970;
				my $ret = sprintf("%.0f%06d0",$windsec,$us);
				$ret; 
			} else {
				$_;
			}
		}
	],
);


sub conv_none		{ return $_[0] }

sub ldap_convert_attr ($$$)
{
	my ($attr, $value, $dir) = @_;
	my $at = $all_lc_attrs{user}{lc($attr)};
	for (keys %all_lc_attrs) {
		last if $at;
		$at = $all_lc_attrs{$_}{lc($attr)};
	}
	my $sub;
	if (defined $at) {
		$sub = $at->{$dir ? 'sub_disp2attr' : 'sub_attr2disp'};
	}
	return defined($sub) ? &$sub($value) : $value;
}

sub ldap_attr2disp ($$)		{ return ldap_convert_attr($_[0], $_[1], 0); }
sub ldap_disp2attr ($$)		{ return ldap_convert_attr($_[0], $_[1], 1); }


sub ldap_print_entry ($$$)
{
	my ($entry, $atts, $msg) = @_;
	my ($attr, %atts);
	$atts = '*' if nvl($atts) eq '';
	if ($atts ne '*') {
		for $attr (split(/,/, $atts)) {
			$atts{$attr} = 1;
		}
	}
	my $len = 80 - length($msg);
	my $hr = '=' x ($len > 0 ? $len / 2 : 1);
	print "$hr $msg $hr\n";
	my $fmt = "%28s: [%s] ";
	print sprintf($fmt,"dn",nvl($entry->dn))."\n";
	for $attr ($entry->attributes) {
		next unless $atts eq '*' || $atts{$attr};  
		my @vals = $entry->get_value($attr);
		foreach my $v1 (@vals) {
			my $value = ldap_attr2disp($attr, $v1);
			my $v2 = ldap_disp2attr($attr, $value);
			my $ok = ($v1 eq $v2);
			$ok = $ok ? "" : " ERROR! [$v1] <> [$v2]";
			print sprintf($fmt,$attr,$value)."$ok\n";
		}
	}
	print "$HR\n\n";
}


# ======== Logging ========


sub log_msg
{
	my ($level, $fmt, @args) = @_;
	$fmt = $translations{$fmt} if defined $translations{$fmt};
	my $msg = sprintf($fmt, @args);
	my ($s,$mi,$h,$d,$mo,$y) = localtime(time);
	my ($secs, $usecs) = gettimeofday;
	my $ms = int($usecs / 1000);
	my $str = sprintf("%02d:%02d:%02d.%03d [%5s] %s\n", $h,$mi,$s,$ms, $level, $msg);
	if ($level eq 'error') {
		croak($str);
		die;
	}
	print STDERR $str if $level ne 'debug' || $config{debug};
	return $str;
}

sub log_debug	{ log_msg('debug', @_); }
sub log_info	{ log_msg('info', @_); }
sub log_error	{ log_msg('error', @_); }


# ======== gui utils ========


sub create_pic ($)
{
	my $file = $_[0];
	return undef unless defined $file;
	my $path = "$pic_home/$file";
	return $pic_cache{$path} if $pic_cache{$path};
	croak "picture not found: $path\n" unless -r $path;
	$pic_cache{$path} = Gtk2::Gdk::Pixbuf->new_from_file($path);
	return $pic_cache{$path};
}


sub create_button
{
	my ($text, $pic, %props) = @_;
	my $button = $props{toggle} ? Gtk2::ToggleButton->new : Gtk2::Button->new;
	my $box = Gtk2::HBox->new;
	$button->add($box);
	my $image = $button->{__image} = Gtk2::Image->new;
	my $label = $button->{__label} = Gtk2::Label->new;
	if ($props{rightpic}) {
		$box->pack_start($label, 0, 0, 1);
		$box->pack_end($image, 0, 0, 1);		
	} else {
		$box->pack_start($image, 0, 0, 1);
		$box->pack_end($label, 0, 0, 1);
	}
	$label->set_text($text) if $text;
	set_button_image($button, $pic);		
	$button->signal_connect("clicked" => $props{action}) if $props{action};
	$props{owner_box}->pack_start($button, 0, 0, 1) if $props{owner_box};
	return $button;
}


sub set_button_image ($$)
{
	my ($button, $pic) = @_;
	my $image = $button->{__image};
	return unless $image;
	if ($pic) {
		$image->set_from_pixbuf(create_pic($pic));
	} else {
		$image->clear;
	}
}


sub get_button_label ($)
{
	my $button = shift;
	my $label = $button->{__label};
	return $label ? nvl($label->get_text) : ''; 
}


sub create_button_bar
{
	my $hbox = Gtk2::HBox->new;
	my $end = 0;
	for (@_) {
		if ($#{$_} < 0) {
			$end = 1;
			next;
		}
		my ($label, $pic, $action, $var) = @$_;
		my $button = create_button($label, $pic, action => $action);
		$$var = $button if defined $var;
		if ($end) {
			$hbox->pack_end($button, 0, 0, 1);
		} else {
			$hbox->pack_start($button, 0, 0, 1);			
		}
	}
	my $frame = Gtk2::Frame->new;
	$frame->set_shadow_type('etched-in');
	$frame->add($hbox);
	return $frame;
}


sub message_box ($$$)
{
	my ($type, $buttons, $message) = @_;
	my $dia = Gtk2::MessageDialog->new ($main_wnd, 'destroy-with-parent',
										$type, $buttons, $message);
	my $ret = $dia->run;
	$dia->destroy;
	return $ret;
}


sub set_window_icon ($$)
{
	my ($wnd, $pic) = @_;
	$wnd->window->set_icon(undef, create_pic($pic)->render_pixmap_and_mask(1));
}


sub destroy_popup ($$)
{
	my ($wnd, $btn) = @_;
	$btn->set_sensitive(1) if defined $btn;
	$wnd->destroy;
}


sub show_popup
{
	my ($wnd, $popup_btn) = @_;
	$wnd->set_transient_for($main_wnd);
	$wnd->set_position('center_on_parent');
	my $deletable_supported = 1;
	if ($^O eq 'MSWin32') {
		# set_deletable() is not available in GTK+ 2.8 and older on Windows
		$deletable_supported = Gtk2->CHECK_VERSION(2, 9, 0);
	}
	$wnd->set_deletable(0) if $deletable_supported;
	$wnd->set_modal(1);
	$wnd->signal_connect(delete_event	=> sub { destroy_popup($wnd, $popup_btn) });
	$wnd->signal_connect(destroy		=> sub { destroy_popup($wnd, $popup_btn) });
	$popup_btn->set_sensitive(0) if $popup_btn;
	$wnd->show_all;
	set_window_icon($wnd, "popup.png");
}


# ======== conversion ========


sub subst_path
{
	my ($path, %subst) = @_;
	for my $from (keys %subst) {
		$path =~ s/\[$from\]/$subst{$from}/g;		
	}
	$path =~ s{/}{\\}g;
	return $path;
}


sub path2dn
{
	my ($path, $prefix, $split) = @_;
	$prefix = 'cn' unless defined $prefix;
	$split = '\.' unless defined $split;
	return join(",", map("$prefix=$_",split(/$split/, $path)));
}


sub nvl ($)
{
	return '' unless defined $_[0];
	$_ = $_[0];
	s/^\s+//;
	s/\s+$//;
	return $_;
}


sub ifnull ($$)
{
	my ($a, $b) = @_;
	return (defined($a) && defined($b) && $a ne '' && $b ne '') ? $b : '';
}


sub string2id ($)
{
	$_ = shift;
	#tr/АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ/ABVGDEWZIJKLMNOPRSTUFHC4WWXYXEUQ/;
	tr/\x{410}\x{411}\x{412}\x{413}\x{414}\x{415}\x{416}\x{417}\x{418}\x{419}\x{41a}\x{41b}\x{41c}\x{41d}\x{41e}\x{41f}\x{420}\x{421}\x{422}\x{423}\x{424}\x{425}\x{426}\x{427}\x{428}\x{429}\x{42a}\x{42b}\x{42c}\x{42d}\x{42e}\x{42f}/ABVGDEWZIJKLMNOPRSTUFHC4WWXYXEUQ/;
	#tr/абвгдежзийклмнопрстуфхцчшщъыьэюя/abvgdewzijklmnoprstufhc4wwxyxeuq/;		
	tr/\x{430}\x{431}\x{432}\x{433}\x{434}\x{435}\x{436}\x{437}\x{438}\x{439}\x{43a}\x{43b}\x{43c}\x{43d}\x{43e}\x{43f}\x{440}\x{441}\x{442}\x{443}\x{444}\x{445}\x{446}\x{447}\x{448}\x{449}\x{44a}\x{44b}\x{44c}\x{44d}\x{44e}\x{44f}/abvgdewzijklmnoprstufhc4wwxyxeuq/;		
	$_ = lc;
	s/^\s+//;
	s/\s+$//;
	s/\s+/ /g;
	tr/0-9a-z/_/cs;
	my $maxlen = 16;
	$_ = substr($_, 0, $maxlen) if length > $maxlen;
	return $_;
}


sub split_list ($)
{
	my $s = shift;
	$s =~ s/^\s+//;
	$s =~ s/\s+$//;
	$s =~ s/\s+/ /g;
	return split(/(\s*[,;: ]\s*)+/, $s);
}


sub join_list (@)
{
	return join(',', @_);
}


# ========  attributes  ========


sub create_obj ($)
{
	my $objtype = shift;
	my $descs = $all_attrs{$objtype};
	log_error('unknown object type "%s"', $objtype) unless $descs;
	my $obj = {
		type => $objtype,
		changed => 0,
		a => {},
		ldap => {},
		attrlist => {},
	};
	$obj->{names} = [];
	$obj->{attrs} = [];
	for my $name (sort keys %$descs) {
		my $desc = $descs->{$name};
		my $at = {
			obj => $obj,
			name => $name,
			desc => $desc,
			type => $desc->{type},
			state => undef,
			visual => 0,
			entry => undef,
			bulb => undef,
		};
		$obj->{a}->{$name} = $at;
		$at->{orig} = $at->{cur} = $at->{usr} = $at->{val} = undef;
		push @{$obj->{names}}, $name;
		push @{$obj->{attrs}}, $at;
	}
	for my $srv (keys %servers) {
		$obj->{attrlist}{$srv} = $servers{$srv}{attrlist}{$objtype};
	}
	return clear_obj($obj);
}


sub clear_obj
{
	my $obj = shift;
	for my $at (@{$obj->{attrs}}) {
		$at->{val} = $at->{cur} = $at->{orig} = $at->{usr} = '';
		$at->{entry}->set_text('') if $at->{entry};		
		$at->{state} = 'empty';
		set_attr_state($at, 'refresh') if $at->{bulb};
	}
	for my $srv (keys %servers) {
		$obj->{ldap}{$srv} = undef;
	}
	$obj->{changed} = 0;
	return $obj;
}


sub get_attr_node ($$)
{
	my ($obj, $name) = @_;
	my $at = $obj->{a}->{$name};
	log_error('attribute "%s" undefined in object "%s"', $name, $obj->{type}) unless $at;
	return $at;
}


sub init_attr ($$$)
{
	my ($obj, $name, $visual) = @_;
	my $at = get_attr_node($obj, $name);
	$at->{label} = $at->{entry} = $at->{bulb} = $at->{popup} = undef;
	$at->{visual} = $visual;
	if ($visual) {
		log_error('%s attribute "%s" cannot be visual', $obj->{type}, $name)
			unless $at->{desc}{visual};
		$at->{label} = Gtk2::Label->new($at->{desc}{label});
		$at->{label}->set_justify('left');
		$at->{entry} = Gtk2::Entry->new;
		$at->{entry}->{friend} = $at;
		$at->{bulb} = Gtk2::Image->new if $visual & 2;
		if ($at->{type} =~ m/^(g|G|U)$/) {
			$at->{popup} = create_button(undef, 'popup.png');
			$at->{popup}->set_relief('none');
		}
	}
	$at->{val} = $at->{cur} = $at->{orig} = $at->{usr} = '';
	$at->{state} = 'empty';
	return $at;
}


sub commit_attrs($)
{
	my $obj = shift;
	for my $at (@{$obj->{attrs}}) {
		$at->{cur} = $at->{val};
		$obj->{changed} = 1 if $at->{cur} ne $at->{orig};
	}
	return $obj;
}


sub has_attr ($$)
{
	my ($obj, $name) = @_;
	my $at = get_attr_node($obj, $name);
	my $state = nvl($at->{state});
	return $state2has{$state} if defined $state2has{$state};
	return nvl($at->{cur}) ne '' ? 1 : 0;
}


sub get_attr ($$@)
{
	my ($obj, $name, %param) = @_;
	my $at = get_attr_node($obj, $name);
	return '' unless defined $at;
	my $which = defined $param{which} ? $param{which} : 'cur';
	return nvl($at->{$which});
}


sub set_attr ($$$)
{
	my ($obj, $name, $val) = @_;
	my $at = get_attr_node($obj, $name);
	$at->{val} = $val;
	if ($at->{orig} ne $at->{val}) {
		my $sdn = nvl($obj->{dn});
		$sdn = ($sdn =~ /^\s*(.*?)\s*,/) ? $1 : '???';
		log_debug('(%s): [%s] := (%s)', $sdn, $name, $val);
	}
	return $at;
}


sub cond_set ($$$)
{
	my ($obj, $name, $val) = @_;
	my $has = has_attr($obj, $name);
	set_attr($obj, $name, $val) unless $has;
	return $has;
}


# ========  ldap readers and writers  ========


%ldap_rw_subs = (
	s => [ \&ldap_read_string, \&ldap_write_string, \&ldap_write_none ],
	d => [ \&ldap_read_string, \&ldap_write_string, \&ldap_write_none ],
	c => [ \&ldap_read_class, \&ldap_write_class, \&ldap_write_none ],
	g => [ \&ldap_read_gidn, \&ldap_write_gidn, \&ldap_write_none ],
	G => [ \&ldap_read_unix_groups, \&ldap_write_unix_groups, \&ldap_write_unix_groups_final ],
	U => [ \&ldap_read_unix_members, \&ldap_write_unix_members, \&ldap_write_unix_members_final ],
	a => [ \&ldap_read_ad_pri_group, \&ldap_write_ad_pri_group, \&ldap_write_none ],
	A => [ \&ldap_read_ad_sec_groups, \&ldap_write_none, \&ldap_write_ad_sec_groups_final ],
);


sub ldap_write_none ($$$$)
{
	return 0;
}


sub ldap_read_string ($$$)
{
	my ($at, $ldap, $name) = @_;
	return nvl($ldap->get_value($name));
}


sub ldap_write_string ($$$$)
{
	my ($at, $ldap, $name, $val) = @_;
	my $changed = 0;
	if ($val eq '') {
		if ($ldap->exists($name)) {
			$ldap->delete($name);
			$changed = 1;
			log_debug('set_ldap_attr(%s): remove', $name);
		} else {
			#log_debug('set_ldap_attr(%s): already removed', $name);
		}
	} elsif ($ldap->exists($name)) {
		my $old = nvl($ldap->get_value($name));
		if ($val ne $old) {
			$ldap->replace($name => $val);
			$changed = 1;
			log_debug('set_ldap_attr(%s): "%s" -> "%s"', $name, $old, $val);
		} else {
			#log_debug('set_ldap_attr(%s): preserve "%s"', $attr, $val);			
		}
	} else {
		$ldap->add($name => $val);
		$changed = 1;
		log_debug('set_ldap_attr(%s): add "%s"', $name, $val);			
	}
	return $changed;
}


sub ldap_read_class ($$$)
{
	my ($at, $ldap, $name) = @_;
	return join_list sort $ldap->get_value('objectClass');
}


sub ldap_write_class ($$$$)
{
	my ($at, $ldap, $name, $val) = @_;
	my $changed = 0;
	my %ca;
	for my $c ($ldap->get_value('objectClass')) {
		$ca{lc($c)} = 1;
	}
	for my $c (split_list $val) {
		next if defined $ca{lc($c)};
		$ldap->add(objectClass => $c);
		$changed = 1;
	}
	return $changed;
}


sub ldap_read_gidn ($$$)
{
	my ($at, $ldap, $name) = @_;
	my $val = nvl($ldap->get_value($at->{name}));
	if ($val =~ /^\d+$/) {
		#log_debug('search for group id %d', $val);
		my $res = ldap_search($uni, "(&(objectClass=posixGroup)(gidNumber=$val))");
		my $grp = $res->pop_entry;
		if ($grp) {
			my $cn = $grp->get_value('cn');
			$val = $cn if $cn;
		} else {
			log_debug('cannot find group id %d (error: %s)', $val, $res->error);
		}
	}
	return $val;
}


sub ldap_write_gidn ($$$$)
{
	my ($at, $ldap, $name, $val) = @_;
	if ($val !~ /^\d*$/) {
		my $cn = $val;
		$val = 0;
		my $res = ldap_search($uni, "(&(objectClass=posixGroup)(cn=$cn))", [ 'gidNumber' ]);
		my $grp = $res->pop_entry;
		if ($grp) {
			my $gidn = $grp->get_value('gidNumber');
			$val = $gidn if $gidn;
		}
		log_info('set_ldap_attr: group "%s" not found', $cn) unless $val;
	}
	log_debug('set_ldap_attr: set group to "%s"', $val);
	return ldap_write_string ($at, $ldap, $name, $val);
}


sub ldap_read_unix_groups ($$$)
{
	my ($at, $ldap, $name) = @_;
	my $uidn = nvl($ldap->get_value($name));
	$uidn = get_attr($at->{obj}, $name) unless $uidn;
	my $res = ldap_search($uni, "(&(objectClass=posixGroup)(memberUid=$uidn))", [ 'cn' ]);
	return join_list sort map { $_->get_value('cn') } $res->entries;
}


sub get_group_ids ($$)
{
	my ($val, $warn) = @_;
	my @ids = split_list $val;
	log_debug('list for "%s" is "%s"', $val, join_list(@ids));
	return () if $#ids < 0;
	my (%ids, @gidns, $grp);
	map { $ids{$_} = 1 } @ids;
	my $s = join '', map { /^\d+$/ ? "(cn=$_)(gidNumber=$_)" : "(cn=$_)" } @ids;
	$s = "(&(objectClass=posixGroup)(|$s))";
	log_debug('request for "%s" is "%s"', $val, $s);
	my $res = ldap_search($uni, $s, [ 'cn', 'gidNumber' ]);
	for $grp ($res->entries) {
		my $gidn = $grp->get_value('gidNumber');
		my $cn = $grp->get_value('cn');
		delete $ids{$gidn};
		delete $ids{$cn};
		push @gidns, $gidn;
	}
	if ($warn eq 'warn' && scalar(keys %ids) > 0) {
		message_box('error', 'close', _T('Groups not found: %s', join_list(keys %ids)));
	}
	@gidns = sort {$a cmp $b} @gidns;
	log_debug('final list is "%s"', join_list @gidns);
	return @gidns;
}


sub modify_unix_group ($$$)
{
	my ($gidn, $uidn, $action) = @_;
	log_debug('will be %s\'ing user %d in group %d...', $action, $uidn, $gidn);
	my $res = ldap_search($uni, "(&(objectClass=posixGroup)(gidNumber=$gidn))",
							[ 'memberUid' ]);
	my $grp = $res->pop_entry;
	if ($res->code || !$grp) {
		log_info('cannot find unix group %d for modification', $gidn);
		return $res->error;
	}
	my (@old, @cur, $exists);
	$exists = $grp->exists('memberUid');
	@old =  $exists ? sort {$a cmp $b} $grp->get_value('memberUid') : ();
	for (@old) { push @cur, $_ if $_ != $uidn }
	push @cur, $uidn if $action eq 'add';
	@cur = sort {$a cmp $b} @cur;
	if (0 && $#old == $#cur) {
		log_info('unix group %d will not change with user %d: (%s) == (%s)',
				$gidn, $uidn, join_list(@old), join_list(@cur));
		return 'SAME';
	}
	if ($exists) {
		$grp->replace('memberUid' => \@cur);
	} else {
		$grp->add('memberUid' => \@cur);		
	}
	$res = ldap_update($uni, $grp);
	my $retval;
	if ($res->code) {
		log_info('%s user %d in group %d error: %s',
				$action, $uidn, $gidn, $res->error);
		$retval = $res->error;
	} else {
		log_debug('success %s\'ing user %d in group %d: [%s] -> [%s]...',
					$action, $uidn, $gidn, join_list(@old), join_list(@cur));
		$retval = 'OK';
	}
	my $sel_grp = $group_obj;
	if (!$sel_grp->{changed} && get_attr($sel_grp, 'gidNumber') eq $gidn) {
		# refresh gui for this group
		group_select();
	}
	return $retval;
}


sub ldap_write_unix_groups_final ($$$$)
{
	my ($at, $ldap, $name, $val) = @_;
	my (%old, %cur);
	return 0 if $at->{orig} eq $at->{cur};
	for (get_group_ids($at->{orig}, 'nowarn')) { $old{$_} = $_ }
	for (get_group_ids($at->{cur}, 'warn')) { $cur{$_} = $_ }
	my $uidn = get_attr($at->{obj}, $name);
	my $changed = 0;
	for my $gidn (sort {$a cmp $b} keys %old) {
		next if $cur{$gidn};
		modify_unix_group($gidn, $uidn, 'remove');
		$changed = 1;
	}
	for my $gidn (sort {$a cmp $b} keys %cur) {
		next if $old{$gidn};
		modify_unix_group($gidn, $uidn, 'add');
		$changed = 1;
	}
	return $changed;
}


sub ldap_read_unix_members ($$$)
{
	my ($at, $ldap, $name) = @_;
	my @uidns = $ldap->get_value($name);
	log_debug('ldap_read_unix_members: "%s" is (%s)', $name, join_list @uidns);
	my @uids = ();
	for my $uidn (@uidns) {
		my $res = ldap_search($uni, "(&(objectClass=person)(uidNumber=$uidn))", [ 'uid' ]);
		my $ue = $res->pop_entry;
		my $uid = $ue ? nvl($ue->get_value('uid')) : '';
		if ($uid ne '') {
			push @uids, $uid;
		} else {
			push @uids, $uidn;
		}
	}
	my $val = join_list sort @uids;
	log_debug('ldap_read_unix_members: "%s" returns "%s"...', $name, $val);
	return $val;
}


sub ldap_write_unix_members ($$$$)
{
	my ($at, $ldap, $name, $val) = @_;
	my (@uidns, %uidns, %touched_uidns);
	for my $uid (split_list $val) {
		if ($uid =~ /^\d+/) {
			push(@uidns, $uid);
			next;
		}
		my $res = ldap_search($uni, "(&(objectClass=person)(uid=$uid))", [ 'uidNumber' ]);
		my $ue = $res->pop_entry;
		my $uidn = $ue ? $ue->get_value('uidNumber') : -1;
		log_debug('search for uid="%s" returns uidn=%d (code=%d)', $uid, $uidn, $res->code);
		if ($uidn != -1) {
			$uidns{$uidn} = $touched_uidns{$uidn} = 1;
		} else {
			log_info('did not find user uid "%s"', $uid);
		}
	}

	@uidns = sort {$a cmp $b} keys %uidns;
	log_debug('ldap_write_unix_members: uidns "%s"; "%s" => [%s]',
				$name, $val, join_list @uidns);
	if ($#uidns < 0) {
		if ($ldap->exists($name)) {
			for ($ldap->get_value($name)) { $touched_uidns{$_} = 1 }
			$ldap->delete($name);
		}
	} elsif ($ldap->exists($name)) {
		for ($ldap->get_value($name)) { $touched_uidns{$_} = 1 }
		$ldap->replace($name => \@uidns);
	} else {
		$ldap->add($name => \@uidns);			
	}

	my $sel_usr = $user_obj;
	if (!$sel_usr->{changed} && $touched_uidns{get_attr($sel_usr, 'uidNumber')}) {
		# will refresh gui for this user after commit to LDAP
		$sel_usr->{refresh_request} = 1;
		log_debug('will re-select currect user');
	}

	return 1;
}


sub ldap_write_unix_members_final ($$$$)
{
	my ($at, $ldap, $name, $val) = @_;
	my $sel_usr = $user_obj;
	if ($sel_usr->{refresh_request}) {
		# refresh gui for this user
		log_debug('re-selecting user');
		$sel_usr->{refresh_request} = 0;
		user_select();
	}
	return 0;
}


sub ldap_read_ad_pri_group ($$$)
{
	my ($at, $ldap, $name) = @_;
	my $pgname = $config{ad_primary_group};
	my $res = ldap_search($ads, "(&(objectClass=group)(cn=$pgname))", [ 'PrimaryGroupToken' ]);
	my $gid = 0;
	my $group = $res->pop_entry;
	$gid = $group->get_value('PrimaryGroupToken') if defined $group;
	$gid = 0 unless $gid;
	if ($res->code || !defined($group) || !$gid) {
		message_box('error', 'close',
			_T('Error reading Windows group "%s" (%s): %s', $name, $gid, $res->error));
	}
	return $gid;
}


sub ldap_write_ad_pri_group ($$$$)
{
	my ($at, $ldap, $name, $val) = @_;
	# writing not supported: AD refuses to set PrimaryGroupID
	return 0;
}


sub ldap_read_ad_sec_groups ($$$)
{
	my ($at, $ldap, $name) = @_;
	my $filter = join( '', map("(cn=$_)", split_list($config{ad_user_groups})) );
	my $res = ldap_search($ads, "(&(objectClass=group)(|$filter))");
	if ($res->code) {
		message_box('error', 'close',
			_T('Error reading list of Windows groups: %s', $res->error));
	}
	return join_list sort map { $_->get_value('name') } $res->entries;
}


sub ldap_write_ad_sec_groups_final ($$$$)
{
	my ($at, $ldap, $name, $val) = @_;

	my $dn = $at->{obj}->{dn};

	my $filter = join( '', map("(cn=$_)", split_list($config{ad_user_groups})) );
	my $res = ldap_search($ads, "(&(objectClass=group)(|$filter))");
	if ($res->code) {
		message_box('error', 'close',
			_T('Error reading list of Windows groups: %s', $res->error));
	}
	# add to required groups
	for my $grp ($res->entries) {
		my $gname = $grp->get_value('name');
		my %members;
		for ($grp->get_value('member')) { $members{$_} = 1; }
		unless (defined $members{$dn}) {
			$grp->add( member => $dn );
			my $res = ldap_update($ads, $grp);
			if ($res->code) {
				message_box('error', 'close',
					_T('Error adding "%s" to Windows-group "%s": %s',
						get_attr($at->{obj}, 'cn'), $gname, $res->error));
			}
		}
	}
	return 0;
}


# ======== read / write ========


sub unix_user_dn ($)
{
	my $usr = shift;
	my $dn = $config{unix_user_dn};
	my $uid = get_attr($usr, 'uid');
	return undef unless $uid;
	my $cn = get_attr($usr, 'cn');
	$dn =~ s/\[uid\]/$uid/g;
	$dn =~ s/\[cn\]/$uid/g;
	return $dn;
}


sub windows_user_dn ($)
{
	my $usr = shift;
	my $cn = get_attr($usr, 'cn');
	return sprintf('cn=%s,%s,%s', $cn,
					path2dn($config{ad_user_container}), path2dn($config{ad_domain},'dc'));
}


sub user_read ($$)
{
	my ($usr, $uid) = @_;
	$usr = $usr ? clear_obj($usr) : create_obj('user');
	return $usr unless $uid;
	my ($cn, $msg);

	$msg = read_ldap_obj_at($usr, 'uni', "(&(objectClass=person)(uid=$uid))");
	message_box('error', 'close', _T('Cannot display user "%s"', $uid).": ".$msg) if $msg;
	$usr->{dn} = nvl($usr->{ldap}{uni}->dn);

	$uid = get_attr($usr, 'uid');
	$cn = get_attr($usr, 'cn');
	$msg = read_ldap_obj_at($usr, 'ads', "(&(objectClass=user)(cn=$cn))");
	log_info('will create windows user "%s" for uid "%s"', $cn, $uid) if $msg;			
	$usr->{ads_dn} = nvl($usr->{ldap}{ads}->dn);

	return $usr;
}


sub read_ldap_obj_at ($$)
{
	my ($obj, $srv, $filter) = @_;

	if ($servers{$srv}{disable}) {
		$obj->{ldap}{srv} = Net::LDAP::Entry->new;
		return undef;
	}

	my $res = ldap_search($servers{$srv}{ldap},	$filter, $obj->{attrlist}{$srv});
	if ($res->code || scalar($res->entries) == 0) {
		$obj->{ldap}{$srv} = Net::LDAP::Entry->new;
		return $res->error;
	}
	my $ldap = $obj->{ldap}{$srv} = $res->pop_entry;

	for my $at (@{$obj->{attrs}}) {
		next unless $at->{state} eq 'empty';
		my $name = $at->{desc}{ldap}{$srv};
		next unless $name;
		my $val = nvl( &{$at->{desc}{ldap_read}} ($at, $ldap, $name) );
		$at->{val} = $at->{cur} = $at->{orig} = $at->{usr} = $val;
		$at->{state} = $val eq '' ? 'empty' : 'orig';
		if ($at->{entry}) {
			$at->{entry}->set_text($at->{val});
			$at->{entry}->set_editable(1);
		}
		set_attr_state($at, 'refresh') if $at->{bulb};
	}

	return 0;
}


sub user_write ($)
{
	my $usr = shift;
	return unless $usr->{changed};
	my $msg;

	$usr->{dn} = unix_user_dn($usr) unless $usr->{dn};
	$msg = write_ldap_obj_at($usr, 'uni', $usr->{dn});
	if ($msg) {
		message_box('error', 'close',
			_T('Error saving user "%s" (%s): %s', get_attr($usr, 'uid'), $usr->{dn}, $msg));
	}

	$usr->{ads_dn} = windows_user_dn($usr) unless $usr->{ads_dn};
	$msg = write_ldap_obj_at($usr, 'ads', $usr->{ads_dn});
	if ($msg) {
		message_box('error', 'close',
				_T('Error updating Windows-user "%s" (%s): %s',
					get_attr($usr, 'cn'), $usr->{ads_dn}, $msg));
	}

	return $usr;
}


sub write_ldap_obj_at ($$$)
{
	my ($obj, $srv, $dn) = @_;
	return undef if $servers{$srv}{disable};
	my $ldap = $obj->{ldap}{$srv};
	my $changed = 0;
	my $msg;

	for my $at (@{$obj->{attrs}}) {
		my $name = $at->{desc}{ldap}{$srv};
		next unless $name;
		$changed |= &{$at->{desc}{ldap_write}} ($at, $ldap, $name, nvl($at->{cur}));
	}

	if ($changed) {
		$ldap->dn($dn);
		my $res = ldap_update($servers{$srv}{ldap}, $ldap);
		# Note: code 82 = `no values to update'
		$msg = $res->error if $res->code && $res->code != 82;
	}

	for my $at (@{$obj->{attrs}}) {
		my $name = $at->{desc}{ldap}{$srv};
		next unless $name;
		$changed |= &{$at->{desc}{ldap_write_final}} ($at, $ldap, $name, nvl($at->{cur}));
	}

	return $msg;
}


# ========  reworking  ========


sub next_unix_uidn
{
	return $next_uidn if defined($next_uidn) && $next_uidn > 0;
	$next_uidn = 0;
	for (ldap_search($uni, '(objectClass=posixAccount)', [ 'uidNumber' ])->entries) {
		my $uidn = $_->get_value('uidNumber');
		$next_uidn = $uidn if $uidn > $next_uidn;
	}
	$next_uidn = $next_uidn > 0 ? $next_uidn + 1 : 1000;
	log_debug('next uidn: %d', $next_uidn);
	return $next_uidn;
}


sub next_unix_gidn
{
	return $next_gidn if defined($next_gidn) && $next_gidn > 0;
	$next_gidn = 0;
	for (ldap_search($uni, '(objectClass=posixGroup)', [ 'gidNumber' ])->entries) {
		my $gidn = $_->get_value('gidNumber');
		$next_gidn = $gidn if $gidn > $next_gidn;
	}
	$next_gidn = $next_gidn > 0 ? $next_gidn + 1 : 1000;
	log_debug('next gidn: %d', $next_gidn);
	return $next_gidn;
}


sub rework_accounts (@)
{
	my @ids = @_;
	#log_debug('rework ids: %s', join_list(@ids));
	@ids = map { $_->get_value('uid') }
				ldap_search($uni, "(objectClass=person)", [ 'uid' ])->entries
		if $#ids < 0;
	for my $id (@ids) {
		log_debug('rework id %s ...', $id);
		my $usr = user_read(undef, $id);
		if ($usr) {
			rework_user($usr);
			commit_attrs($usr);
			user_write($usr);
			rework_home_dir($usr) unless $config{nodirs};
		}
	}
}


sub rework_user ($)
{
	my $usr = shift;

	# read all scalar attributes
	my $uid = get_attr($usr, 'uid');
	my $cn = get_attr($usr, 'cn');
	my $gn = get_attr($usr, 'givenName');
	my $sn = get_attr($usr, 'sn');

	############# POSIX ############

	# name
	cond_set($usr, 'cn', $cn = $gn . ($sn && $gn ? ' ' : '') . $sn)
		unless has_attr($usr, 'cn');

	# identifier
	$uid = $sn eq '' ? $gn : substr($gn, 0, 1) . $sn
		unless has_attr($usr, 'uid');
	set_attr($usr, 'uid', $uid = string2id($uid));

	# add the required classes (works directly on ldap entry !)
	set_attr($usr, 'objectClass', $config{unix_user_classes});

	# assign next available UID number
	my $uidn;
	if (has_attr($usr, 'uidNumber')) {
		$uidn = get_attr($usr, 'uidNumber');
		$uidn =~ tr/0123456789//cd;
	} else {
		$uidn = next_unix_uidn();
	}
	set_attr($usr, 'uidNumber', $uidn);

	# mail
	cond_set($usr, 'mail', ifnull($uid, $uid.'@'.$config{unix_domain}));

	# home directory
	cond_set($usr, 'homeDirectory', ifnull($uid, "/home/$uid"));

	# constant and copy-from fields
	for my $at (values %{$usr->{a}}) {
		my $desc = $at->{desc};
		if ($desc->{default}) {
			cond_set($usr, $at->{name}, $desc->{default});
		}
		if ($desc->{copyfrom}) {
			my $val = get_attr($usr, $desc->{copyfrom});
			if ($val ne '') {
				cond_set($usr, $at->{name}, $val);
			}
		}
	}

	############# Active Directory ############

	set_attr($usr, 'objectClass', $config{ad_user_classes});

	cond_set($usr, 'objectCategory', join_list(path2dn($config{ad_user_category}),
												path2dn($config{ad_domain},'dc')));

	my %path_subst = (SERVER => $config{home_server}, USER => $uid);

	cond_set($usr, 'ntUserHomeDir',
			ifnull($uid, subst_path($config{ad_home_dir}, %path_subst)));

	cond_set($usr, 'ntUserProfile',
			ifnull($uid, subst_path($config{ad_profile_path}, %path_subst)));

	cond_set($usr, 'ntUserScriptPath',
			ifnull($uid, subst_path($config{ad_script_path}, %path_subst)));

	cond_set($usr, 'ntUserDomainId', $uid);

	cond_set($usr, 'userPrincipalName', $uid.'@'.$config{ad_domain});	

	# FIXME! passwords...
	if (0 && defined($config{ad_initial_pass})) {
		my $unipwd = "";
		map { $unipwd .= "$_\000" } split(//, "\"$config{ad_initial_pass}\"");
		cond_set($usr, 'unicodePwd', $unipwd);
	}

	# constant and copy-from fields
	for my $at (@{$usr->{attrs}}) {
		my $desc = $at->{desc};
		cond_set($usr, $at->{name}, $desc->{default}) if defined $desc->{default};
		cond_set($usr, $at->{name}, get_attr($usr, $desc->{copyfrom}))
			if $desc->{copyfrom};
	}
}


sub rework_home_dir ($)
{
	my $usr = shift;
	my $home = get_attr($usr, 'homeDirectory');
	return 0 if $home eq '';
	return 2 if -d $home;

	log_info('creating home directory "%s"', $home);
	$install{src} = $config{skel_dir};
	$install{dst} = $home;
	$install{uidn} = get_attr($usr, 'uidNumber');
	$install{gidn} = get_attr($usr, 'gidNumber');

	my $ret = File::Copy::Recursive::rcopy($install{src}, $install{dst});
	find(sub {
			# FIXME: is behaviour `lchown'-compatible ?
			chown $install{uidn}, $install{gidn}, $File::Find::name;
		}, $install{dst});
	return $ret > 0 ? 1 : -1;
}


# NOTE: structure of this routine is correct
#       user reworking routines shouls work the same way
sub rework_unix_group ($)
{
	my $grp = shift;

	set_attr($grp, 'objectClass', $config{unix_group_classes});

	my $val = get_attr($grp, 'cn');
	set_attr($grp, 'cn', string2id($val));

	$val = get_attr($grp, 'gidNumber');
	$val = next_unix_gidn() unless $val;
	$val =~ tr/0123456789//cd;
	set_attr($grp, 'gidNumber', $val);

	my $dn = $config{unix_group_dn};
	for my $at (@{$grp->{attrs}}) {
		$dn =~ s/\[$at->{name}\]/$at->{val}/g;
		last if $dn !~ /\[\w+\]/;
	}
	$grp->{dn} = $dn;
}


# ======== connections ========


sub ldap_search
{
	my ($srv, $filter, $attrs, %params) = @_;
	$params{filter} = $filter;
	$params{base} = $srv->{cfg}->{base} unless $params{base};
	$params{attrs} = $attrs if $attrs;
	my $res = $srv->search(%params);
	return $res;
}


sub ldap_update ($$)
{
	my ($srv, $ent) = @_;
	my $res = $ent->update($srv);
	undef $next_uidn;
	undef $next_gidn;
	return $res;
}


sub ldap_delete ($$)
{
	my ($srv, $ent) = @_;
	my $res = $srv->delete($ent);
	return $res;
}


sub ldap_connect
{
	my $ref = shift;
	my $cfg = $servers{$ref};
	my ($ldap, $mesg, $entry);

	if ($cfg->{disable}) {
		$ldap = Net::LDAP->new;
		$ldap->{cfg} = $cfg;
		$cfg->{ldap} = $ldap;
		return $ldap;
	}

	my ($uri, $user) = ($cfg->{uri}, $cfg->{user});
	my ($pass, $pfile) = ($cfg->{pass}, $cfg->{passfile});

	if (!$pass && $pfile) {
		open (PFILE, $pfile) or log_error('cannot open passfile "%s"', $pfile);
		$pass = "";
		while (<PFILE>) {
			chomp;
			next if /^\s*$/;
			s/^\s*//; s/\s*$//;
			$pass = $_;
			last;
		}
		close PFILE;
	}
	unless ($uri && $user && $pass) {
		log_error('invalid credentials for %s', $ref);
	}
 
	$ldap = Net::LDAP->new($uri, debug => $cfg->{debug})
		or log_error('cannot connect to %s: %s', $uri, $@);
	$mesg = $ldap->bind($user, password => $pass);
	log_error('cannot bind as %s: %s', $ref, $mesg->error) if $mesg->code;
	$ldap->{cfg} = $cfg;
	$cfg->{ldap} = $ldap;
	return $ldap;
}


sub connect_all
{
	$uni = ldap_connect('uni');
	$ads = ldap_connect('ads');	
}


sub disconnect_all
{
	$uni->unbind unless $uni->{cfg}->{disable};
	$ads->unbind unless $ads->{cfg}->{disable};
}


# ======== user gui =========


sub set_attr_state ($$)
{
	my ($at, $state) = @_;
	if ($state ne 'refresh') {
		if ($state eq 'auto') {
			my $val = nvl($at->{val});
			if ($val eq '') { $state = 'empty'; }
			elsif ($val eq nvl($at->{orig})) { $state = 'orig'; }
			elsif ($val eq nvl($at->{prev})) { $state = $at->{prev_state}; }
			elsif ($val eq nvl($at->{usr})) { $state = 'user'; }
			else { $state = 'calc'; }
		}
		$at->{state} = $state;
	}
	if (defined $at->{bulb}) {
		if ($state eq 'refresh' || !defined($at->{prev_state})
				|| $state ne $at->{prev_state}) {
			my $pic =  $state2pic{$at->{state}};
			$pic = 'empty.png' unless defined $pic;
			$at->{bulb}->set_from_pixbuf(create_pic($pic));
		}
	}
}


sub is_new_user ($)
{
	my $node = shift;
	my $model = $user_list->get_model;
	return 0 unless defined $node;
	my $uid = $model->get($node, 0);
	my $cn = $model->get($node, 1);
	my $is_new_user = $uid eq '-' && $cn eq '-';
	return $is_new_user ? 1 : 0;
}


sub user_save
{
	my ($path, $column) = $user_list->get_cursor;
	return unless defined $path;
	my $usr = $user_obj;
	return unless $usr->{changed};

	my $model = $user_list->get_model;
	my $node = $model->get_iter($path);
	my $uid = get_attr($usr, 'uid');
	my $cn = get_attr($usr, 'cn');
	$model->set($node, 0, $uid, 1, $cn);

	user_write($usr);
	user_select();
	set_user_changed(0);
	$btn_usr_add->set_sensitive(1);
}


sub user_revert
{
	my $resp = message_box('question', 'yes-no', _T('Really revert changes ?'));
	return if $resp ne 'yes';
	set_user_changed(0);
	$btn_usr_add->set_sensitive(1);
	user_select();
}


sub user_add
{
	user_unselect();
	my $list = $user_list;
	my $model = $list->get_model;
	my $usr = $user_obj;

	my $node = $model->get_iter_first;
	while (defined $node) {
		return if is_new_user($node);
		$node = $model->iter_next($node);
	}

	$node = $model->append(undef);
	$model->set($node, 0, '-', 1, '-');
	my $path = $model->get_path($node);
	$list->set_cursor($path);
	get_attr_node($usr, $gui_attrs{user}[0][0])->{entry}->grab_focus;
	set_user_changed(0);
	$btn_usr_add->set_sensitive(0);
	user_select($path, 0);
}


sub user_delete
{
	my ($path, $column) = $user_list->get_cursor;
	my $model = $user_list->get_model;
	return unless defined $path;

	my $node = $model->get_iter($path);
	my $uid = $model->get($node, 0);
	my $usr = $user_obj;
	my $list = $user_list;

	if (is_new_user($node)) {
		my $resp = message_box('question', 'yes-no', _T('Cancel new user ?', $uid));
		return if $resp ne 'yes';		
	} else {
		my $resp = message_box('question', 'yes-no', _T('Delete user "%s" ?', $uid));
		return if $resp ne 'yes';

		my $res = ldap_delete($uni, $usr->{ldap});
		if ($res->code) {
			message_box('error', 'close',
					_T('Error deleting Unix-user "%s": %s', $uid, $res->error));
			return;
		}

		my $uidn = get_attr($usr, 'uidNumber');
		my $gid_list = get_attr($usr, 'moreGroups', which => 'orig');
		$gid_list .= (nvl($gid_list) eq '' ? '' : ',') . get_attr($usr, 'gidNumber');
		my @gid_list = get_group_ids($gid_list, 'nowarn');
		for my $gidn (sort {$a cmp $b} @gid_list) {
			modify_unix_group($gidn, $uidn, 'remove');
		}

		unless ($ads->{cfg}->{disable}) {
			my $ads_dn = windows_user_dn($usr);
			$res = ldap_delete($ads, $ads_dn);
			if ($res->code) {
				message_box('error', 'close',
					_T('Error deleting Windows-user "%s": %s', $uid, $res->error));
			}
		}
	}

	$model->remove($node);
	set_user_changed(0);
	$btn_usr_add->set_sensitive(1);

	if ($path->prev || $path->next) {
		$list->set_cursor($path);
		user_select();
	} else {
		user_unselect();
	}
}


sub users_refresh
{
	user_unselect();
	rework_accounts();

	my @attrs = ('uid', 'cn');
	my $model = $user_list->get_model;
	$model->clear;

	my $res = ldap_search($uni, "(objectClass=person)", \@attrs);
	my @users = $res->entries;
	@users = sort { $a->get_value('uid') cmp $b->get_value('uid') } @users;

	for my $entry (@users) {
		my $node = $model->append(undef);
		for my $i (0 .. $#attrs) {
			$model->set($node, $i, nvl($entry->get_value($attrs[$i])));
		}
	}

	$btn_usr_add->set_sensitive(1) if defined $btn_usr_add;
}


sub user_change
{
	my ($path, $column) = $user_list->get_cursor;
	my $model = $user_list->get_model;
	if (defined $path) {
		my $node = $model->get_iter($path);
		$model->remove($node) if is_new_user($node);
		$btn_usr_add->set_sensitive(1);
	}
}


sub user_unselect
{
	# exit if interface is not built complete
	return unless defined $user_name;
	my $usr = $user_obj;

	$user_name->set_text('');

	for my $at (values %{$user_obj->{a}}) {
		next unless $at->{visual};
		$at->{entry}->set_text('');
		$at->{entry}->set_editable(0);
		$at->{bulb}->set_from_pixbuf(create_pic('empty.png'));
	}

	for ($btn_usr_apply, $btn_usr_revert, $btn_usr_delete) { $_->set_sensitive(0); }

	$user_attr_tabs->set_current_page(0);
	$user_attr_frame->set_sensitive(0);

	undef $usr->{ldap};
	undef $usr->{dn};
	$usr->{changed} = 0;

	return 0;
}


sub user_select
{
	my ($path, $column) = $user_list->get_cursor;
	return unless defined $path;

	my $model = $user_list->get_model;
	my $node = $model->get_iter($path);
	my $uid = $model->get($node, 0);
	my $cn = $model->get($node, 1);
	return unless defined $uid;

	my $usr = $user_obj;
	my $at;

	if (is_new_user($node)) {
		$usr->{ldap} = Net::LDAP::Entry->new;
		for $at (values %{$usr->{a}}) { $at->{cur} = ''; set_ldap_attr($at); }
	} else {
		my $res = ldap_search($uni, "(&(objectClass=person)(uid=$uid))");
		if ($res->code || scalar($res->entries) == 0) {
			my $msg = _T('Cannot display user "%s"', $uid);
			$msg .= ": ".$res->error if $res->code;
			message_box('error', 'close', $msg);
			return;
		}
		$usr->{ldap} = $res->pop_entry;
	}

	for $at (values %{$usr->{a}}) {
		get_ldap_attr($at);
		next unless $at->{visual};
		log_debug('set attr %s to %s', $at->{name}, $at->{val}) if $at->{type} eq 'G';
		$at->{entry}->set_text($at->{val});
		$at->{entry}->set_editable(1);
		set_attr_state($at, 'refresh');
	}

	$user_name->set_text("$uid ($cn)");
	$btn_usr_delete->set_sensitive(1);
	$user_attr_tabs->set_current_page(0);
	$user_attr_frame->set_sensitive(1);
}


sub user_entry_attr_changed
{
	my $entry1 = shift;
	my $a1 = $entry1->{friend};
	return unless $a1;
	my $usr = $a1->{obj};
	return unless $usr;

	$a1->{val} = $a1->{usr} = nvl($a1->{entry}->get_text);
	return if $a1->{cur} eq $a1->{val};

	# calculate calculatable fields
	my $at;
	for $at (values %{$usr->{a}}) {
		$at->{prev_state} = $at->{state};
		$at->{prev} = $at->{cur};
		$at->{cur} = $at->{val};
	}
	my $chg = $usr->{changed};
	$a1->{state} = 'user';
	rework_unix_account_entry($usr);
	$usr->{changed} = $chg;

	# analyze results
	$chg = 0;
	for $at (values %{$usr->{a}}) {
		next unless $at->{visual};
		my $val = $at->{cur} = nvl($at->{val});
		set_attr_state($at, 'auto');
		if ($val ne $at->{usr}) {
			my $entry = $at->{entry};
			my $pos = $entry->get_position;
			$entry->set_text($val);
			$entry->set_position($pos);
		}
		$chg = 1 if $val ne $at->{orig};
	}

	# refresh top label
	my $uid = get_attr($usr, 'uid');
	my $cn = get_attr($usr, 'cn');
	my $new_name = "$uid ($cn)";
	$user_name->set_text($new_name) if $user_name->get_text ne $new_name;

	# refresh buttons
	set_user_changed($chg);
}


sub set_user_changed
{
	my $chg = shift;
	my $usr = $user_obj;
	return if $chg == $usr->{changed};
	$usr->{changed} = $chg;
	for ($btn_usr_apply, $btn_usr_revert) { $_->set_sensitive($chg) }
	for ($btn_usr_refresh, $btn_usr_add, $btn_usr_delete, $user_list) { $_->set_sensitive(!$chg) }
}


sub user_group_toggled ($$)
{
	my ($btn, $at) = @_;
	my $uid = get_button_label($btn);
	my $active = $btn->get_active;
	set_button_image($btn, $toggle_icon[$active ? 1:0]);

	my @groups;
	for (split_list $at->{entry}->get_text) {
		next unless $_;
		push @groups, $_ if $_ ne $uid;	
	}
	push @groups, $uid if $active;
	my $val = join_list sort @groups;
	$at->{val} = $at->{cur} = $at->{usr} = $val;
	$at->{entry}->set_text($val);
	set_user_changed(1) if $val ne $at->{orig};
	set_attr_state($at, 'auto');
}


sub create_user_groups_editor ($)
{
	my $at = shift;
	my $popup_btn = $at->{popup};

	my $res = ldap_search($uni, "(objectClass=posixGroup)", ['cn']);
	my @groups = $res->entries;
	return if $#groups < 0;

	my $wnd = Gtk2::Window->new("toplevel");
	$wnd->set_title("Other Groups...");
	my $vbox = Gtk2::VBox->new(0, 0);
	$wnd->add($vbox);
	my $scroll = Gtk2::ScrolledWindow->new;
	$vbox->pack_start($scroll, 1, 1, 1);
	$scroll->set_policy("automatic", "automatic");
	my $list = new Gtk2::VBox(0, 0);
	$scroll->add_with_viewport($list);

	my %groups0;
	map { $groups0{$_} = 1 } split_list $at->{entry}->get_text;	

	for my $gid (sort {$a cmp $b} map {$_->get_value('cn')} @groups) {
		my $btn = create_button($gid, undef, toggle => 1, rightpic => 1);
		$btn->signal_connect(toggled => sub { user_group_toggled($btn, $at); });
		my $active = defined $groups0{$gid};
		set_button_image($btn, $toggle_icon[$active ? 1:0]);
		$btn->set_active($active);
		$btn->set_relief('none');
		my $frame = Gtk2::Frame->new;
		$frame->add($btn);
		$list->pack_start($frame, 0, 0, 0);
		$list->pack_start(Gtk2::HSeparator->new, 0, 0, 0);
	}

	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) } ],
	);

	$vbox->pack_end($buttons, 0, 0, 2);
	$wnd->set_default_size(150, 200);
	show_popup($wnd, $popup_btn);
}


sub user_group_selected
{
	my ($at, $list) = @_;
	my ($path, $column) = $list->get_cursor;
	my $model = $list->get_model;
	my $node = $model->get_iter($path);
	my $val = $model->get($node, 0);
	$at->{val} = $at->{cur} = $at->{usr} = $val;
	$at->{entry}->set_text($val);
	set_user_changed(1) if $val ne $at->{orig};
	set_attr_state($at, 'auto');
}


sub create_group_chooser ($)
{
	my $at = shift;
	my $popup_btn = $at->{popup};

	my $res = ldap_search($uni, "(objectClass=posixGroup)", [ 'cn', 'gidNumber' ]);
	my @groups = $res->entries;
	return if $#groups < 0;

	my $wnd = Gtk2::Window->new("toplevel");
	$wnd->set_title("Main Group");
	my $vbox = Gtk2::VBox->new(0, 0);
	$wnd->add($vbox);

	my $list = Gtk2::TreeView->new;
	$list->set_rules_hint(1);
	$list->get_selection->set_mode('single');

	my $model = Gtk2::TreeStore->new(qw(Glib::String Glib::String));
	$list->set_model($model);

	my @titles = (_T('Group'));
	for my $k (0 .. $#titles) {
		my $renderer = Gtk2::CellRendererText->new;
		my $off = $list->insert_column_with_attributes(-1, $titles[$k], $renderer, text => $k);
		$list->get_column($off - 1)->set_clickable(1);
	}
	$list->set_headers_visible(0);

	$list->signal_connect(cursor_changed => sub { user_group_selected($at, $list) });

	my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
	$scroll->set_policy('automatic', 'automatic');  
	$scroll->add_with_viewport($list);

	my $frame = Gtk2::Frame->new;
	$frame->set_shadow_type('in');
	$frame->add($scroll);
	$vbox->pack_start($frame, 1, 1, 1);

	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) } ],
	);
	$vbox->pack_end($buttons, 0, 0, 2);

	my $cur_grp_id = $at->{entry}->get_text;
	@groups = sort { $a->get_value('cn') cmp $b->get_value('cn') } @groups;
	for my $grp (@groups) {
		my $node = $model->append(undef);
		my $gidn = nvl($grp->get_value('gidNumber'));
		my $cn = nvl($grp->get_value('cn'));
		$model->set($node, 0, $cn);
		if ($cur_grp_id eq $cn || $cur_grp_id eq $gidn) {
			$list->set_cursor($model->get_path($node));			
		}
	}

	$wnd->set_default_size(150, 200);
	show_popup($wnd, $popup_btn);
}


sub create_user_desc
{
	my $vbox = Gtk2::VBox->new(0, 0);
	my $frame;

	$user_name = Gtk2::Label->new;
	my $bname = Gtk2::Button->new;
	$bname->add($user_name);
	$bname->set_sensitive(0);
	$vbox->pack_start($bname, 0, 1, 4);

	my $tabs = Gtk2::Notebook->new;
	$user_attr_tabs = $tabs;
	$tabs->set_tab_pos("top");
	$frame = Gtk2::Frame->new(_T('Attributes'));
	$frame->add($tabs);
	$user_attr_frame = $frame;
	$vbox->pack_start($frame, 1, 1, 0);

	my $usr = $user_obj;
	set_attr($usr, 'objectClass', '');

	for (@{$gui_attrs{user}}) {
		my ($tab_name, $tab_attrs) = @$_;
		my @tab_attrs = @$tab_attrs;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, $tab_name);
		$scroll->set_policy('automatic', 'automatic');
		$scroll->set_border_width(0);

		my $abox = Gtk2::Table->new($#tab_attrs + 1, 4);
		$scroll->add_with_viewport($abox);

		for my $r (0 .. $#tab_attrs) {
			my $at = init_attr($usr, $tab_attrs[$r], 1);
			$abox->attach($at->{bulb}, 0, 1, $r, $r+1, [], [], 1, 1);
			$abox->attach($at->{label}, 1, 2, $r, $r+1, [], [], 1, 1);
			my $right = 4;
			if ($at->{popup}) {
				my $sub = $at->{type} eq 'g'
							? sub { create_group_chooser($at) }
							: sub { create_user_groups_editor($at) }; 
				$at->{popup}->signal_connect(clicked => $sub);
				$abox->attach($at->{popup}, 3, 4, $r, $r+1, [], [], 1, 1);
				$right = 3;
			}
			$abox->attach($at->{entry}, 2, $right, $r, $r+1, [ 'fill', 'expand' ], [], 1, 1);
			$at->{entry}->signal_connect(key_release_event => \&user_entry_attr_changed)
		}
	}

	my $buttons = create_button_bar(
		[],
		[ _T('Save'), "apply.png", \&user_save, \$btn_usr_apply ],
		[ _T('Revert'), "revert.png", \&user_revert,\$btn_usr_revert ],
	);
	$vbox->pack_end($buttons, 0, 0, 2);

	return $vbox;
}


sub create_user_list
{
	my @user_list_titles = (_T('Identifier'), _T('Full name'));

	$user_list = Gtk2::TreeView->new;
	$user_list->set_rules_hint(1);
	$user_list->get_selection->set_mode('single');
	$user_list->set_size_request(300, 300);

	my $model = Gtk2::TreeStore->new(qw(Glib::String Glib::String));
	$user_list->set_model($model);

	for my $k (0 .. $#user_list_titles) {
		my $renderer = Gtk2::CellRendererText->new;
		my $off = $user_list->insert_column_with_attributes(
						-1, $user_list_titles[$k],
						$renderer, text => $k
					);
		my $column = $user_list->get_column($off - 1);
		$column->set_clickable(1);
	}

	my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
	$scroll->set_policy('automatic', 'automatic');  
	$scroll->add($user_list);

	my $frame = Gtk2::Frame->new;
	$frame->set_shadow_type('in');
	$frame->add($scroll);

	$user_list->signal_connect(cursor_changed => \&user_select);
	$user_list->signal_connect(move_cursor => \&user_change);

	return $frame;
}


# ======== group gui ========


sub is_new_group ($)
{
	my $node = shift;
	my $model = $group_list->get_model;
	return 0 unless defined $node;
	my $gid = $model->get($node, 0);
	return ($gid eq '-' ? 1 : 0);
}


sub group_save
{
	my ($path, $column) = $group_list->get_cursor;
	return unless defined $path;
	my $grp = $group_obj;
	return unless $grp->{changed};

	my $model = $group_list->get_model;
	my $node = $model->get_iter($path);
	my $gid = get_attr($grp, 'cn');
	$model->set($node, 0, $gid);

	my $at = get_attr_node($grp, 'description');
	$at->{cur} = $gid if nvl($at->{cur}) eq '';

	for $at (values %{$grp->{a}}) { set_ldap_attr($at); }
	$grp->{ldap}->dn($grp->{dn}) if $grp->{dn};

	my $res = ldap_update($uni, $grp->{ldap});
	if ($res->code && $res->code != 82) {
		# Note: code 82 = `no values to update'
		message_box('error', 'close',
			_T('Error saving group "%s": %s', $gid, $res->error));
		return;
	}
	for $at (values %{$grp->{a}}) { set_ldap_attr_final($at); }

	group_select();
	set_group_changed(0);
	$btn_grp_add->set_sensitive(1);
}


sub group_revert
{
	my $resp = message_box('question', 'yes-no', _T('Really revert changes ?'));
	return if $resp ne 'yes';
	set_group_changed(0);
	$btn_grp_add->set_sensitive(1);
	group_select();
}


sub group_add
{
	group_unselect();
	my $model = $group_list->get_model;
	my $grp = $group_obj;

	my $node = $model->get_iter_first;
	while (defined $node) {
		return if is_new_group($node);
		$node = $model->iter_next($node);
	}

	$node = $model->append(undef);
	$model->set($node, 0, '-');

	my $path = $model->get_path($node);
	$group_list->set_cursor($path);

	get_attr_node($grp, $gui_attrs{group}[0][0])->{entry}->grab_focus;
	set_group_changed(0);
	$btn_grp_add->set_sensitive(0);

	group_select();
}


sub group_delete
{
	my ($path, $column) = $group_list->get_cursor;
	return unless defined $path;
	my $model = $group_list->get_model;
	my $grp = $group_obj;

	my $node = $model->get_iter($path);
	my $gid = $model->get($node, 0);

	if (is_new_group($node)) {
		my $resp = message_box('question', 'yes-no', _T('Cancel new group ?', $gid));
		return if $resp ne 'yes';		
	} else {
		my $resp = message_box('question', 'yes-no', _T('Delete group "%s" ?', $gid));
		return if $resp ne 'yes';

		my $res = ldap_delete($uni, $grp->{ldap});
		if ($res->code) {
			message_box('error', 'close',
					_T('Error deleting group "%s": %s', $gid, $res->error));
			return;
		}
	}

	$model->remove($node);
	set_group_changed(0);
	$btn_grp_add->set_sensitive(1);

	if ($path->prev || $path->next) {
		$group_list->set_cursor($path);
		group_select();
	} else {
		group_unselect();
	}
}


sub groups_refresh
{
	group_unselect();

	my $model = $group_list->get_model;
	$model->clear;

	my $res = ldap_search($uni, '(objectClass=posixGroup)', ['cn']);
	my @groups = $res->entries;
	@groups = sort { $a->get_value('cn') cmp $b->get_value('cn') } @groups;

	for my $entry (@groups) {
		my $node = $model->append(undef);
		$model->set($node, 0, nvl($entry->get_value('cn')));
	}

	$btn_grp_add->set_sensitive(1) if defined $btn_grp_add;
}


sub group_change
{
	my ($path, $column) = $group_list->get_cursor;
	my $model = $group_list->get_model;
	if (defined $path) {
		my $node = $model->get_iter($path);
		$model->remove($node) if is_new_group($node);
		$btn_grp_add->set_sensitive(1);
	}
}


sub group_unselect
{
	# exit if interface is not built complete
	return unless defined $group_name;
	my $grp = $group_obj;

	$group_name->set_text('');

	for my $at (values %{$grp->{a}}) {
		next unless $at->{visual};
		$at->{entry}->set_text('');
		$at->{entry}->set_editable(0);
	}

	$btn_grp_apply->set_sensitive(0);
	$btn_grp_revert->set_sensitive(0);
	$btn_grp_delete->set_sensitive(0);
	$group_attr_frame->set_sensitive(0);

	undef $grp->{ldap};
	undef $grp->{dn};
	$grp->{changed} = 0;

	return 0;
}


sub group_select
{
	my ($path, $column) = $group_list->get_cursor;
	return unless defined $path;
	my $grp = $group_obj;
	my $model = $group_list->get_model;
	my $node = $model->get_iter($path);
	my $gid = $model->get($node, 0);
	my $at;

	if (is_new_group($node)) {
		$grp->{ldap} = Net::LDAP::Entry->new;
		for $at (values %{$grp->{a}}) { $at->{cur} = ''; set_ldap_attr($at); }
	} else {
		my $res = ldap_search($uni, "(&(objectClass=posixGroup)(cn=$gid))");
		if ($res->code || scalar($res->entries) == 0) {
			my $msg = _T('Cannot display group "%s"', $gid);
			$msg .= ": ".$res->error if $res->code;
			message_box('error', 'close', $msg);
			return;
		}
		$grp->{ldap} = $res->pop_entry;
		$grp->{dn} = $grp->{ldap}->dn;
	}

	for $at (values %{$grp->{a}}) {
		get_ldap_attr($at);
		next unless $at->{visual};
		$at->{entry}->set_text($at->{val});
		$at->{entry}->set_editable(1);
	}

	$group_name->set_text($gid);
	$btn_grp_delete->set_sensitive(1);
	$group_attr_frame->set_sensitive(1);
}


sub group_entry_attr_changed
{
	my $entry1 = shift;
	my $a1 = $entry1->{friend};
	return unless $a1;
	my $grp = $a1->{obj};
	return unless $grp;

	$a1->{val} = $a1->{usr} = nvl($a1->{entry}->get_text);
	return if $a1->{cur} eq $a1->{val};
	$a1->{cur} = $a1->{val};

	rework_unix_group($grp);

	my $chg = 0;
	for my $at (values %{$grp->{a}}) {
		$chg = 1 if $at->{val} ne $at->{orig};
		next if $at->{val} eq $at->{cur};
		$at->{cur} = $at->{val};
		next unless $at->{visual};
		my $entry = $at->{entry};
		my $pos = $entry->get_position;
		$entry->set_text($at->{val});
		$entry->set_position($pos);
	}

	$group_name->set_text(get_attr($grp, 'cn'));
	set_group_changed($chg);
}


sub set_group_changed
{
	my $chg = shift;
	my $grp = $group_obj;
	return if $chg == $grp->{changed};
	$grp->{changed} = $chg;
	for ($btn_grp_apply, $btn_grp_revert) { $_->set_sensitive($chg) }
	for ($btn_grp_refresh, $btn_grp_add, $btn_grp_delete, $group_list) { $_->set_sensitive(!$chg) }
}


sub group_user_toggled ($$)
{
	my ($btn, $at) = @_;
	my $uid = get_button_label($btn);
	my $active = $btn->get_active;
	set_button_image($btn, $toggle_icon[$active ? 1:0]);

	my @users = ();
	for (split_list $at->{entry}->get_text) {
		next unless $_;
		push @users, $_ if $_ ne $uid;	
	}
	push @users, $uid if $active;
	$at->{val} = $at->{cur} = join_list sort @users;
	set_group_changed(1) if $at->{val} ne $at->{orig};
	$at->{entry}->set_text($at->{val});
}


sub create_group_users_editor ($)
{
	my $at = shift;
	my $popup_btn = $at->{popup};

	my $res = ldap_search($uni, "(objectClass=person)", ['uid']);
	my @users = $res->entries;
	return if $#users < 0;

	my $wnd = Gtk2::Window->new("toplevel");
	$wnd->set_title("Users in Group");
	my $vbox = Gtk2::VBox->new(0, 0);
	$wnd->add($vbox);
	my $scroll = Gtk2::ScrolledWindow->new;
	$vbox->pack_start($scroll, 1, 1, 1);
	$scroll->set_policy("automatic", "automatic");
	my $list = new Gtk2::VBox(0, 0);
	$scroll->add_with_viewport($list);

	my (%users0, %users);
	for (split_list $at->{entry}->get_text) { $users0{$_} = 1 }

	for (@users) { $users{$_->get_value('uid')} = 1 }
	for (keys %users0) { $users{$_} = 1 }

	for my $uid (sort {$a cmp $b} keys %users) {
		my $btn = create_button($uid, undef, toggle => 1, rightpic => 1);
		$btn->signal_connect(toggled => sub { group_user_toggled($btn, $at); });
		my $active = defined $users0{$uid};
		set_button_image($btn, $toggle_icon[$active ? 1:0]);
		$btn->set_active($active);
		$btn->set_relief('none');
		my $frame = Gtk2::Frame->new;
		$frame->add($btn);
		$list->pack_start($frame, 0, 0, 0);
		$list->pack_start(Gtk2::HSeparator->new, 0, 0, 0);
	}

	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) } ],
	);

	$vbox->pack_end($buttons, 0, 0, 2);
	$wnd->set_default_size(150, 200);
	show_popup($wnd, $popup_btn);
}


sub create_group_desc
{
	my $vbox = Gtk2::VBox->new(0, 0);
	my $frame;

	$group_name = Gtk2::Label->new;
	my $bname = Gtk2::Button->new;
	$bname->add($group_name);
	$bname->set_sensitive(0);
	$vbox->pack_start($bname, 0, 1, 4);

	my $tabs = Gtk2::Notebook->new;
	$tabs->set_tab_pos("top");
	$frame = Gtk2::Frame->new(_T('Attributes'));
	$frame->add($tabs);
	$group_attr_frame = $frame;
	$vbox->pack_start($frame, 1, 1, 0);

	my $grp = $group_obj;
	set_attr($grp, 'objectClass', '');

	for (@{$gui_attrs{group}}) {
		my ($tab_name, $tab_attrs) = @$_;
		my @tab_attrs = @$tab_attrs;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, $tab_name);
		$scroll->set_policy('automatic', 'automatic');
		$scroll->set_border_width(0);

		my $abox = Gtk2::Table->new($#tab_attrs + 1, 3);
		$scroll->add_with_viewport($abox);

		for my $r (0 .. $#tab_attrs) {
			my $at = init_attr($grp, $tab_attrs[$r], 1);
			$abox->attach($at->{label}, 0, 1, $r, $r+1, [], [], 1, 1);
			my $right = 3;
			if ($at->{popup}) {
				my $popup_btn = create_button(undef, 'popup.png');
				$at->{popup} = $popup_btn;
				$popup_btn->signal_connect(clicked =>
								sub { create_group_users_editor($at); });
				$popup_btn->set_relief('none');
				$abox->attach($popup_btn, 2, 3, $r, $r+1, [], [], 1, 1);
				$right = 2;
			}
			$abox->attach($at->{entry}, 1, $right, $r, $r+1, [ 'fill', 'expand' ], [], 1, 1);
			$at->{entry}->signal_connect(key_release_event => \&group_entry_attr_changed);
		}
	}

	my $buttons = create_button_bar(
		[],
		[ _T('Save'), "apply.png", \&group_save, \$btn_grp_apply ],
		[ _T('Revert'), "revert.png", \&group_revert,\$btn_grp_revert ],
	);
	$vbox->pack_end($buttons, 0, 0, 2);

	return $vbox;
}


sub create_group_list
{
	$group_list = Gtk2::TreeView->new;
	$group_list->set_rules_hint(1);
	$group_list->get_selection->set_mode('single');
	$group_list->set_size_request(300, 300);

	my $model = Gtk2::TreeStore->new('Glib::String');
	$group_list->set_model($model);

	my $off = $group_list->insert_column_with_attributes(
					-1, _T('Group name'), Gtk2::CellRendererText->new, text => 0);
	$group_list->get_column($off - 1)->set_clickable(1);

	my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
	$scroll->set_policy('automatic', 'automatic');  
	$scroll->add($group_list);

	my $frame = Gtk2::Frame->new;
	$frame->set_shadow_type('in');
	$frame->add($scroll);

	$group_list->signal_connect(cursor_changed => \&group_select);
	$group_list->signal_connect(move_cursor => \&group_change);

	return $frame;
}


# ======== main ========


sub gui_exit
{
	if ($user_obj->{changed} || $group_obj->{changed}) {
		my $resp = message_box('question', 'yes-no', _T('Exit and loose changes ?'));
		return 1 if $resp ne 'yes';
		$user_obj->{changed} = $group_obj->{changed} = 0;
	}
	user_unselect();
	group_unselect();
	Gtk2->main_quit;
}


sub gui_main
{
	($pname = $0) =~ s/^.*\///;
	my %opts;
	my $cmd_ok = getopts("Dhd", \%opts);

	my $fh = select(STDOUT); $| = 1; select($fh);
	log_error('usage: $pname [-d] [-D]') if !$cmd_ok || $opts{h};

	configure(@{$config{config_files}});
	dump_config() if $opts{D};
	$config{debug} = 1 if $opts{d};

	setup_attrs();
	connect_all();

	my $gtkrc; # for future...
	Gtk2::Rc->parse($gtkrc) if defined $gtkrc;
	$main_wnd = Gtk2::Window->new('toplevel');
	$main_wnd->set_title('Account Manager');

	my $tabs = Gtk2::Notebook->new;
	$tabs->set_tab_pos('top');

	my $vbox = Gtk2::VBox->new;
	$tabs->append_page($vbox, _T(' Users '));
	my $hpane = Gtk2::HPaned->new;
	$hpane->add1(create_user_list());
	$hpane->add2(create_user_desc());
	my $buttons = create_button_bar (
		[ _T('Create'), "add.png", \&user_add, \$btn_usr_add ],
		[ _T('Delete'), "delete.png", \&user_delete, \$btn_usr_delete ],
		[ _T('Refresh'), "refresh.png", \&users_refresh, \$btn_usr_refresh ],
		[],
		[ _T('Exit'), "exit.png", \&gui_exit ],
	);
	$vbox->pack_start($hpane, 1, 1, 1);
	$vbox->pack_end($buttons, 0, 0, 1);

	$vbox = Gtk2::VBox->new;
	$tabs->append_page($vbox, _T(' Groups '));
	$hpane = Gtk2::HPaned->new;
	$hpane->add1(create_group_list());
	$hpane->add2(create_group_desc());
	$buttons = create_button_bar (
		[ _T('Create'), "add.png", \&group_add, \$btn_grp_add ],
		[ _T('Delete'), "delete.png", \&group_delete, \$btn_grp_delete ],
		[ _T('Refresh'), "refresh.png", \&groups_refresh, \$btn_grp_refresh ],
		[],
		[ _T('Exit'), "exit.png", \&gui_exit ],
	);
	$vbox->pack_start($hpane, 1, 1, 1);
	$vbox->pack_end($buttons, 0, 0, 1);

	$main_wnd->add($tabs);
	user_unselect();
	group_unselect();

	$main_wnd->signal_connect(delete_event	=> \&gui_exit);
	$main_wnd->signal_connect(destroy		=> \&gui_exit);
	$main_wnd->signal_connect(map	=> sub {
								# initialize interface data
								users_refresh();
								groups_refresh();
							});

	$main_wnd->set_default_size(900, 600);
	$main_wnd->show_all;
	set_window_icon($main_wnd, "userman.png");

	Gtk2->main;

	disconnect_all();
}

gui_main();
