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
use File::Find;
use File::Copy::Recursive;
use Net::LDAP;
use Net::LDAP::Entry;
use Net::LDAP::Extension::SetPassword;
use Unicode::Map8;
use Unicode::String qw(utf16);

use FindBin qw[$Bin];
use Cwd 'abs_path';

my ($pname, $main_wnd, %install);

my ($btn_usr_apply, $btn_usr_revert, $btn_usr_add, $btn_usr_delete, $btn_usr_refresh);
my ($user_list, $user_attr_frame, $user_attr_tabs, $user_name, $user_obj);

my ($btn_grp_apply, $btn_grp_revert, $btn_grp_add, $btn_grp_delete, $btn_grp_refresh);
my ($group_list, $group_attr_frame, $group_name, $group_obj);

my ($next_uidn, $next_gidn);

my $pic_home = abs_path("$Bin/images");
my %pic_cache;

my %ldap_rw_subs;

use constant NO_EXPIRE => '9223372036854775807';
use constant SAM_USER_OBJECT => hex('0x30000000');
use constant SECS1610TO1970 => 11644473600;
use constant OLD_PASS => '~~~Q@#Rt==%%%&//z!!!';

use constant ADS_UF_ACCOUNT_DISABLE => 0x2; 	  
use constant ADS_UF_PASSWD_NOT_REQUIRED => 0x20;
use constant ADS_UF_NORMAL_ACCOUNT => 0x200;
use constant ADS_UF_DONT_EXPIRE_PASSWD => 0x10000;


sub _T($@);


# ======== config =========


my %servers = (
	uni => { disable => 1 },	# Unix LDAP Server
	ads => { disable => 1 },	# Windows Active Directory
);


my %config = (
	config_files		=>	[
		'/etc/userman.conf',
		'~/.userman.conf',
		'./userman.conf'
	],
	unix_user_classes	=>	'top,person,organizationalPerson,inetOrgPerson,posixAccount,shadowAccount',
							# 'ntUser',
	unix_group_classes	=>	'top,posixGroup',	
	ad_user_classes		=>	'top,user,person,organizationalPerson',	
	ad_user_category	=>	'Person.Schema.Configuration',
	language			=>	'ru',
);


my %translations = (
	ru => {
		'Domain Users'	=>	'Пользователи домена',
		'Remote Users'	=>	'Пользователи удаленного рабочего стола',
		'Name'			=>	'Имя',
		'Second name'	=>	'Фамилия',
		'Full name'		=>	'Полное имя',
		'Identifier'	=>	'Идентификатор',
		'Password'		=>	'Пароль',
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
		'Error deleting Windows-user "%s" (%s): %s'	=>	'Ошибка удаления Windows-пользователя "%s" (%s): %s',
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
	},
);


my %all_attrs = (
	########## user ##########
	user => {
		dn => {
			type => 'D',
			ldap => 'uni',
			label => 'UNIX DN',
			readonly => 1,
		},
		ntDn => {
			type => 'D',
			ldap => 'ads',
			label => 'Windows DN',
			readonly => 1,
		},
		objectClass => {
			type => 'c',
			ldap => { uni => 'objectClass' },
		},
		ntObjectClass => {
			type => 'c',
			ldap => { ads => 'objectClass' },
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
			ldap => 'uni,ads',
		},
		uid => {
			type => 'd',
			label => 'Identifier',
			ldap => 'uni,ads',
		},
		password => {
			type => 'p',
			label => 'Password',
			ldap => { uni => 'userPassword', ads => 'unicodePwd' },
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
			label => 'Expires at',
		},
		sAMAccountName => {
			ldap => 'ads',
			copyfrom => 'uid',
		},
		displayName => {
			ldap => 'ads',
			copyfrom => 'cn',
		},
		instanceType => {
			default => '4',
			ldap => 'ads',
		},
		userAccountControl=> {
			conv => 'decihex',
			label => 'Account control',
			ldap => 'ads',
		},
		userPrincipalName => {
			ldap => 'ads',
			label => 'Principal name'
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
			ldap => 'ntuser',
			disable => 1,
		},
		ntUserDomainId => {
			ldap => 'ntuser',
			copyfrom => 'uid',
			disable => 1,
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
		objectCategory => { disable => 1 },
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
		objectClass => {
			type => 'c',
			ldap => 'uni',
		},
		dn => {
			type => 'D',
			ldap => 'uni',
			label => 'DN'
		},
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
		[ 'UNIX', qw(givenName sn cn uid mail uidNumber
					gidNumber moreGroups homeDirectory loginShell
		) ],
		[ 'Windows', qw(ntUserHomeDir ntUserHomeDirDrive
						ntUserProfile ntUserScriptPath
						accountExpires userAccountControl userPrincipalName
						password dn ntDn
		) ],
		[ 'Communigate', ],
		[ 'Extended', qw(telephoneNumber facsimileTelephoneNumber
		) ],
	],
	group => [
		[ 'UNIX', qw(cn gidNumber description memberUid
					dn
		) ],
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


sub configure (@)
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


sub dump_config ()
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


sub setup_attrs ()
{
	for my $objtype ('user', 'group') {

		for my $cfg (values %servers) { $cfg->{attrhash}{$objtype} = {} }
		$all_lc_attrs{$objtype} = {};
		my $descs = $all_attrs{$objtype};

		for my $name (keys %$descs) {

			my $desc = $descs->{$name};
			$all_lc_attrs{$objtype}->{lc($name)} = $desc;

			$desc->{name} = $name;
			$desc->{type} = 's' unless $desc->{type};
			$desc->{visual} = $desc->{label} ? 1 : 0;
			$desc->{label} = _T($desc->{label}) if $desc->{label};
			$desc->{readonly} = 0 unless $desc->{readonly};
			
			$desc->{conv} = 'none' unless $desc->{conv};
			for my $dir (0, 1) {
				my $sub;
				$sub = $convtype2subs{$desc->{conv}}->[$dir]
					if defined $convtype2subs{$desc->{conv}};
				$sub = \&conv_none unless $sub;
				$desc->{$dir ? 'disp2attr' : 'attr2disp'} = $sub;
			}

			log_error('%s attribute "%s" is copy-from unknown "%s"',
						$objtype, $name, $desc->{copyfrom})
				if $desc->{copyfrom} && !$descs->{$desc->{copyfrom}};

			$desc->{disable} = 0 unless $desc->{disable};
			my $ldap = $desc->{ldap};

			if (ref $ldap) {
				log_error('incorrect ldap definition in attribute "%s"', $name)
					if ref($ldap) ne 'HASH';
			} else {
				my @ldap = split_list($ldap);
				$ldap = {};
				for (@ldap) { $ldap->{$_} = '' }
			}

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

				my $ldapattr = $ldap->{$srv};
				my $cfg = get_server($srv);
				if ($cfg->{attrhash}{$objtype}{$ldapattr}) {
					log_debug('duplicate attribute "%s" as "%s" for server "%s"',
							$name, $ldapattr, $srv);
				}
				$cfg->{attrhash}{$objtype}{$ldapattr} = 1 unless $ldap->{disable};
			}

			$desc->{ldap} = $ldap;
			$desc->{disable} = 1 unless scalar keys %$ldap;

			my $subs = $ldap_rw_subs{$desc->{disable} ? 'n' :$desc->{type}};
			log_error('type "%s" of "%s" attribute "%s" is not supported',
						$desc->{type}, $objtype, $name) unless $subs;
			$desc->{ldap_read} = $subs->[0];
			$desc->{ldap_write} = $subs->[1];
			$desc->{ldap_write_final} = $subs->[2];
		}
		for my $cfg (values %servers) {
			$cfg->{attrlist}{$objtype} = [ sort keys %{$cfg->{attrhash}{$objtype}} ];
		}
	}
}


# ======= Visualization =========


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
	print '=' x 48 . "\n\n";
}


# ======== Logging ========


sub _T ($@) {
	my $fmt = shift;
	my $tr = $translations{$config{language}};
	$fmt = $tr->{$fmt} if defined $tr->{$fmt};
	return sprintf($fmt, map { defined($_) ? $_ : '<undef>' } @_);
}


sub log_msg ($$@)
{
	my $level = shift;
	my $fmt = shift;
	my $msg = _T($fmt, @_);
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

sub log_debug (@)	{ log_msg('debug', shift, @_); }
sub log_info (@)	{ log_msg('info', shift, @_); }
sub log_error (@)	{ log_msg('error', shift, @_); }


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


sub create_button ($$%)
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
	} elsif (Gtk2->CHECK_VERSION(2, 9, 0)) {
		$image->clear;
	} else {
		$image->set_from_pixbuf(undef);
	}
}


sub get_button_label ($)
{
	my $button = shift;
	my $label = $button->{__label};
	return $label ? nvl($label->get_text) : ''; 
}


sub create_button_bar (@)
{
	my $hbox = Gtk2::HBox->new;
	my $end = 0;
	for (@_) {
		if ($#{$_} < 0) {
			$end = 1;
			next;
		}
		my ($label, $pic, $action, $var) = @$_;
		my $button;
		if (!defined($label) && nvl($action) eq 'pic') {
			$button = Gtk2::Image->new_from_pixbuf(create_pic($pic));
		} else {
			$button = create_button($label, $pic, action => $action);
		}
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
	log_debug($message);
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


sub show_popup ($$)
{
	my ($wnd, $popup_btn) = @_;
	$wnd->set_transient_for($main_wnd);
	$wnd->set_position('center_on_parent');
	# set_deletable() is not available in GTK+ 2.8 and older on Windows
	$wnd->set_deletable(0) if Gtk2->CHECK_VERSION(2, 9, 0);
	$wnd->set_modal(1);
	$wnd->signal_connect(delete_event	=> sub { destroy_popup($wnd, $popup_btn) });
	$wnd->signal_connect(destroy		=> sub { destroy_popup($wnd, $popup_btn) });
	$popup_btn->set_sensitive(0) if $popup_btn;
	$wnd->show_all;
	set_window_icon($wnd, "popup.png");
}


# ======== conversion ========


sub subst_path ($%)
{
	my ($path, %subst) = @_;
	for my $from (keys %subst) {
		$path =~ s/\[$from\]/$subst{$from}/g;		
	}
	$path =~ s{/}{\\}g;
	return $path;
}


sub path2dn ($;$$)
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
	my @r = sort split /(?:\s*[,;: ]\s*)+/, nvl(shift);
	return wantarray ? @r : join(',', @r);
}


sub join_list (@)
{
	return nvl(join ',', sort @_);
}


sub append_list ($$)
{
	my ($a, $b) = @_;
	$a = [ split_list $a ] unless ref $a;
	$b = [ split_list $b ] unless ref $b;
	log_error('invalid append_list arguments') if ref($a) ne 'ARRAY' || ref($b) ne 'ARRAY';
	my (%r, $x);
	for $x (@$a, @$b) { $r{$x} = 1 if nvl($x) ne ''; }
	return wantarray ? sort(keys %r) : join_list(keys %r);
}


sub remove_list ($$)
{
	my ($a, $b) = @_;
	$a = [ split_list $a ] unless ref $a;
	$b = [ split_list $b ] unless ref $b;
	log_error('invalid remove_list arguments') if ref($a) ne 'ARRAY' || ref($b) ne 'ARRAY';
	my (%r, $x);
	for $x (@$a) { $r{$x} = 1 if nvl($x) ne ''; }
	for $x (@$b) { delete $r{$x} }
	return wantarray ? sort(keys %r) : join_list(keys %r);
}


sub compare_lists ($$)
{
	my ($a, $b) = @_;
	$a = [ split_list $a ] unless ref $a;
	$b = [ split_list $b ] unless ref $b;
	log_error('invalid compare_lists arguments') if ref($a) ne 'ARRAY' || ref($b) ne 'ARRAY';
	my (%a, %b, %onlya, %onlyb, %common);
	for (@$a) { $a{$_} = 1 }
	for (@$b) { $b{$_} = 1 }
	for (@$a) { $b{$_} ? ($common{$_} = 1) : ($onlya{$_} = 1) }
	for (@$b) { $a{$_} ? ($common{$_} = 1) : ($onlyb{$_} = 1) }
	return (join_list(keys %onlya), join_list(keys %onlyb), join_list(keys %common));
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
		push @{$obj->{names}}, $name;
		push @{$obj->{attrs}}, $at;
	}
	for my $srv (keys %servers) {
		$obj->{attrlist}{$srv} = $servers{$srv}{attrlist}{$objtype};
	}
	return clear_obj($obj);
}


sub clear_obj ($)
{
	my $obj = shift;
	for my $at (@{$obj->{attrs}}) {
		$at->{val} = $at->{old} = '';
		$at->{entry}->set_text('') if $at->{entry};
		$at->{state} = 'empty';
	}
	for (keys %servers) { $obj->{ldap}{$_} = Net::LDAP::Entry->new; }
	$obj->{changed} = 0;
	update_obj_gui($obj);
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
	my $desc = $at->{desc};
	$at->{visual} = $visual;
	if ($visual) {
		log_error('%s attribute "%s" cannot be visual', $obj->{type}, $name)
			unless $desc->{visual};
		$at->{label} = Gtk2::Label->new($desc->{label});
		$at->{label}->set_justify('left');
		$at->{entry} = Gtk2::Entry->new;
		$at->{entry}->{friend} = $at;
		$at->{entry}->set_editable(!$desc->{disable} && !$desc->{readonly});
		if ($at->{type} eq 'p') {
			#FIXME
			$at->{entry}->set_visibility(0);
			$at->{entry}->set_invisible_char('*');
		}
		if ($at->{type} =~ m/^(g|G|U)$/) {
			$at->{popup} = create_button(undef, 'popup.png');
			$at->{popup}->set_relief('none');
		}
		$at->{bulb} = Gtk2::Image->new if $visual & 2;
	}
	$at->{val} = $at->{old} = '';
	$at->{state} = 'empty';
	return $at;
}


sub obj_changed($)
{
	my $obj = shift;
	for my $at (@{$obj->{attrs}}) {	return 1 if $at->{val} ne $at->{old} }
	return 0;
}


sub has_attr ($$)
{
	my ($obj, $name) = @_;
	my $at = get_attr_node($obj, $name);
	my $state = nvl($at->{state});
	return $state2has{$state} if defined $state2has{$state};
	return nvl($at->{val}) ne '' ? 1 : 0;
}


sub get_attr ($$%)
{
	my ($obj, $name, %param) = @_;
	my $at = get_attr_node($obj, $name);
	return nvl($at->{$param{orig} ? 'old' : 'val'});
}


sub set_attr ($$$)
{
	my ($obj, $name, $val) = @_;

	my $at = get_attr_node($obj, $name);
	$val = nvl($val);
	return $at if $at->{val} eq $val;
	$at->{val} = $val;

	my $state;
	if ($val eq '') {
		$state = 'empty';
	} elsif ($val eq $at->{old}) {
		$state = 'orig';
	} elsif (defined($at->{entry}) && $val eq nvl($at->{entry}->get_text)) {
		$state = 'user';
	} else {
		$state = 'calc';
	}
	$at->{state} = $state;

	my $sdn = nvl(get_attr($obj, 'dn'));
	$sdn = ($sdn =~ /^\s*(.*?)\s*,/) ? $1 : '???';
	log_debug('(%s): [%s] := (%s)', $sdn, $name, $val);

	return $at;
}


sub cond_set ($$$)
{
	my ($obj, $name, $val) = @_;
	my $has = has_attr($obj, $name);
	return 0 if get_attr_node($obj, $name)->{desc}->{disable};
	set_attr($obj, $name, $val) unless $has;
	return $has;
}


# ========  ldap readers / writers  ========


%ldap_rw_subs = (
	n => [ \&ldap_read_none, \&ldap_write_none, \&ldap_write_none ],
	s => [ \&ldap_read_string, \&ldap_write_string, \&ldap_write_none ],
	d => [ \&ldap_read_string, \&ldap_write_string, \&ldap_write_none ],
	D => [ \&ldap_read_dn, \&ldap_write_dn, \&ldap_write_none ],
	c => [ \&ldap_read_class, \&ldap_write_class, \&ldap_write_none ],
	p => [ \&ldap_read_pass, \&ldap_write_pass, \&ldap_write_pass_final ],
	g => [ \&ldap_read_unix_gidn, \&ldap_write_unix_gidn, \&ldap_write_none ],
	G => [ \&ldap_read_unix_groups, \&ldap_write_none, \&ldap_write_unix_groups_final ],
	U => [ \&ldap_read_unix_members, \&ldap_write_unix_members, \&ldap_write_unix_members_final ],
	a => [ \&ldap_read_ad_pri_group, \&ldap_write_ad_pri_group, \&ldap_write_none ],
	A => [ \&ldap_read_ad_sec_groups, \&ldap_write_none, \&ldap_write_ad_sec_groups_final ],
);


sub ldap_read_none ($$$$)
{
	return '';
}


sub ldap_write_none ($$$$$)
{
	return 0;
}


sub ldap_read_string ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	return nvl($ldap->get_value($name));
}


sub ldap_write_string ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my $changed = 0;
	if ($val eq '') {
		if ($ldap->exists($name)) {
			$ldap->delete($name);
			$changed = 1;
			log_debug('ldap_write_string(%s): remove', $name);
		} else {
			#log_debug('ldap_write_string(%s): already removed', $name);
		}
	} elsif ($ldap->exists($name)) {
		my $old = nvl($ldap->get_value($name));
		if ($val ne $old) {
			$ldap->replace($name => $val);
			$changed = 1;
			log_debug('ldap_write_string(%s): "%s" -> "%s"', $name, $old, $val);
		} else {
			#log_debug('ldap_write_string(%s): preserve "%s"', $attr, $val);			
		}
	} else {
		$ldap->add($name => $val);
		$changed = 1;
		log_debug('ldap_write_string(%s): add "%s"', $name, $val);			
	}
	return $changed;
}


sub ldap_read_dn ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	return nvl($ldap->dn);
}


sub ldap_write_dn ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my $prev = nvl($ldap->dn);
	$val = nvl($val);
	log_debug('ldap_write_dn(%s): attr="%s" dn="%s", prev="%s"',
				$srv, $at->{name}, $val, $prev);
	return 0 if $val eq $prev || $val eq '';
	$ldap->dn($val);
	return 1;
}


sub ldap_read_class ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	return join_list $ldap->get_value($name);
}


sub ldap_write_class ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my $changed = 0;
	my %ca;
	for my $c ($ldap->get_value($name)) {
		$ca{lc($c)} = 1;
	}
	for my $c (split_list $val) {
		next if defined $ca{lc($c)};
		$ldap->add($name => $c);
		$changed = 1;
	}
	return $changed;
}


sub ldap_read_unix_gidn ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	my $val = nvl($ldap->get_value($at->{name}));
	if ($val =~ /^\d+$/) {
		my $res = ldap_search('uni', "(&(objectClass=posixGroup)(gidNumber=$val))");
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


sub ldap_write_unix_gidn ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	if ($val !~ /^\d*$/) {
		my $cn = $val;
		$val = 0;
		my $res = ldap_search('uni', "(&(objectClass=posixGroup)(cn=$cn))", [ 'gidNumber' ]);
		my $grp = $res->pop_entry;
		if ($grp) {
			my $gidn = $grp->get_value('gidNumber');
			$val = $gidn if $gidn;
		}
		log_info('ldap_write_gidn: group "%s" not found on %s', $cn) unless $val;
	}
	log_debug('ldap_write_gidn: set group to "%s"', $val);
	return ldap_write_string ($at, $srv, $ldap, $name, $val);
}


sub encode_ad_pass ($)
{
    my $pass = shift;
    my $encoded = '';
    map { $encoded .= "$_\000" } split( //, "\"$pass\"" );
    return $encoded;
}


sub decode_ad_pass ($)
{
    my $pass = shift;
    my $decoded = '';
    for my $char ( split( //, $pass ) ) {
        $char =~ s/\000$//;
        $decoded .= $char;
    }
    $decoded =~ s/^"|"$//g;
    return $decoded;
}


sub ldap_read_pass ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	return OLD_PASS;
}


sub ldap_write_pass ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	return 0 if $val eq OLD_PASS;
	if ($srv eq 'ads') {
		# the following line works only for administrator
		$ldap->replace($name => encode_ad_pass($val));
		return 1;
	}
	return 0;
}


sub ldap_write_pass_final ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my $obj = $at->{obj};
	return 0;
	if ($at->{state} ne 'user') {
		log_debug('no need to change password for %s', get_attr($obj, 'dn'));
		return 0;
	}
	$ldap = get_server($srv, 1)->{ldap};
	my $old = $at->{old};
	my ($dn, $msg);
	if ($srv eq 'uni') {
		$dn = get_attr($obj, 'dn');
		my $extpwd ='1.3.6.1.4.1.4203.1.11.1'; 
		if ($ldap->root_dse->supported_extension($extpwd)) {
			$msg = $ldap->set_password(user => $dn,
								oldpasswd => $old, newpasswd => $val);
		} else {
			$msg = $ldap->modify($dn, changes => [
										delete	=> [ userPassword => $old ],
										add		=> [ userPassword => $val ]
									] );
		}
	}
	if ($msg->code) {
		message_box('error', 'close', _T('Cannot change passowrd for "%s" on "%s": %s',
					$dn, $srv, $msg->error));
	}
	return 0;
}


sub ldap_read_unix_groups ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	my $uidn = nvl($ldap->get_value($name));
	$uidn = get_attr($at->{obj}, $name) unless $uidn;
	my $res = ldap_search($srv, "(&(objectClass=posixGroup)(memberUid=$uidn))", [ 'cn' ]);
	return join_list map { $_->get_value('cn') } $res->entries;
}


sub ldap_get_unix_group_ids ($$$)
{
	my ($srv, $val, $warn) = @_;
	my @ids = split_list $val;
	#log_debug('list for "%s" is "%s"', $val, join_list @ids);
	return wantarray ? () : '' if $#ids < 0;
	my (%ids, @gidns, $grp);
	map { $ids{$_} = 1 } @ids;
	my $s = join '', map { /^\d+$/ ? "(cn=$_)(gidNumber=$_)" : "(cn=$_)" } @ids;
	$s = "(&(objectClass=posixGroup)(|$s))";
	log_debug('request for "%s" is "%s"', $val, $s);
	my $res = ldap_search($srv, $s, [ 'cn', 'gidNumber' ]);
	for $grp ($res->entries) {
		my $gidn = $grp->get_value('gidNumber');
		my $cn = $grp->get_value('cn');
		delete $ids{$gidn};
		delete $ids{$cn};
		push @gidns, $gidn;
	}
	if ($warn eq 'warn' && scalar(keys %ids) > 0) {
		message_box('error', 'close', _T('Groups not found: %s', join_list keys %ids));
	}
	@gidns = sort {$a cmp $b} @gidns;
	log_debug('group list for "%s" is "%s"', $val, join_list @gidns);
	return wantarray ? @gidns : join(',', @gidns);
}


sub ldap_modify_unix_group ($$$$)
{
	my ($srv, $gidn, $uidn, $action) = @_;
	log_debug('will be %s\'ing user %d in group %d...', $action, $uidn, $gidn);
	my $res = ldap_search('uni', "(&(objectClass=posixGroup)(gidNumber=$gidn))",
							[ 'memberUid' ]);
	my $grp = $res->pop_entry;
	if ($res->code || !$grp) {
		log_info('cannot find unix group %d for modification', $gidn);
		return $res->error;
	}
	my ($old, $new, @new, $exists);
	$exists = $grp->exists('memberUid');
	$old =  $exists ? join_list($grp->get_value('memberUid')) : '';
	$new = $action eq 'add' ? append_list($old, $uidn) : remove_list($old, $uidn);
	@new = split_list $new;
	if ($old eq $new) {
		log_debug('unix group %d wont change with user %d: (%s) = (%s)',
				$gidn, $uidn, $old, $new);
		return 'SAME';
	}
	if ($exists) {
		$grp->replace('memberUid' => \@new);
	} else {
		$grp->add('memberUid' => \@new);
	}
	$res = ldap_update('uni', $grp);
	my $retval;
	if ($res->code) {
		log_info('%s user %d in group %d error: %s',
				$action, $uidn, $gidn, $res->error);
		$retval = $res->error;
	} else {
		log_debug('success %s\'ing user %d in group %d: [%s] -> [%s]...',
					$action, $uidn, $gidn, $old, $new);
		$retval = 'OK';
	}
	my $sel_grp = $group_obj;
	if (!$sel_grp->{changed} && get_attr($sel_grp, 'gidNumber') eq $gidn) {
		# refresh gui for this group
		group_load();
	}
	return $retval;
}


sub ldap_write_unix_groups_final ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	return 0 if $at->{old} eq $at->{val};
	my $uidn = get_attr($at->{obj}, $name);
	my $old = ldap_get_unix_group_ids($srv, $at->{old}, 'nowarn');
	my $new = ldap_get_unix_group_ids($srv, $at->{val}, 'warn');
	log_debug('write_unix_groups(1): old=(%s) new=(%s)', $old, $new);
	($old, $new) = compare_lists($old, $new);
	log_debug('write_unix_groups(2): del=(%s) add=(%s)', $old, $new);
	for my $gidn (split_list $old) {
		ldap_modify_unix_group($srv, $gidn, $uidn, 'remove');
	}
	for my $gidn (split_list $new) {
		ldap_modify_unix_group($srv, $gidn, $uidn, 'add');
	}
	return $old ne '' || $new ne '';
}


sub ldap_read_unix_members ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	my @uidns = $ldap->get_value($name);
	log_debug('ldap_read_unix_members: "%s" is (%s)', $name, join_list @uidns);
	my @uids = ();
	for my $uidn (@uidns) {
		my $res = ldap_search($srv, "(&(objectClass=person)(uidNumber=$uidn))", [ 'uid' ]);
		my $ue = $res->pop_entry;
		my $uid = $ue ? nvl($ue->get_value('uid')) : '';
		if ($uid ne '') {
			push @uids, $uid;
		} else {
			push @uids, $uidn;
		}
	}
	my $val = join_list @uids;
	log_debug('ldap_read_unix_members: "%s" returns "%s"...', $name, $val);
	return $val;
}


sub ldap_write_unix_members ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my (@uidns, %uidns, %touched_uidns);
	for my $uid (split_list $val) {
		if ($uid =~ /^\d+/) {
			push(@uidns, $uid);
			next;
		}
		my $res = ldap_search($srv, "(&(objectClass=person)(uid=$uid))", [ 'uidNumber' ]);
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


sub ldap_write_unix_members_final ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my $sel_usr = $user_obj;
	if ($sel_usr->{refresh_request}) {
		# refresh gui for this user
		log_debug('re-selecting user');
		$sel_usr->{refresh_request} = 0;
		user_load();
	}
	return 0;
}


sub ldap_read_ad_pri_group ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	return 0;
	my $pgname = $config{ad_primary_group};
	my $res = ldap_search($srv, "(&(objectClass=group)(cn=$pgname))", [ 'PrimaryGroupToken' ]);
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


sub ldap_write_ad_pri_group ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	# writing not supported: AD refuses to set PrimaryGroupID
	return 0;
}


sub ldap_read_ad_sec_groups ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	return '';

	my $filter = join( '', map("(cn=$_)", split_list $config{ad_user_groups}) );
	my $res = ldap_search($srv, "(&(objectClass=group)(|$filter))");
	if ($res->code) {
		message_box('error', 'close',
			_T('Error reading list of Windows groups: %s', $res->error));
	}
	return join_list map { $_->get_value('name') } $res->entries;
}


sub ldap_write_ad_sec_groups_final ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	return 0;

	my $dn = get_attr($at->{obj}, 'ntDn');

	for my $gname (split_list $config{ad_user_groups}) {
		my $res = ldap_search($srv, "(&(objectClass=group)(cn=$gname))");
		my $grp = $res->pop_entry;
		if ($res->code || !$grp) {
			message_box('error', 'close',
				_T('Error reading Windows group "%s": %s', $gname, $res->error));
			next;
		}
		my $found = 0;
		for ($grp->get_value('member')) {
			if ($_ eq $dn) {
				$found = 1;
				last;
			}
		}
		next if $found;
		$grp->add(member => $dn);
		$res = ldap_update('ads', $grp);
		if ($res->code) {
			message_box('error', 'close',
					_T('Error adding "%s" to Windows-group "%s": %s',
						get_attr($at->{obj}, 'cn'), $gname, $res->error));
		}
	}
	return 0;
}


# ======== read / write ========


sub user_read ($$)
{
	my ($usr, $uid) = @_;
	$usr = $usr ? clear_obj($usr) : create_obj('user');
	return $usr unless $uid;
	my ($cn, $msg);

	unless ($servers{'uni'}{disable}) {
		$msg = ldap_obj_read($usr, 'uni', "(&(objectClass=person)(uid=$uid))");
		message_box('error', 'close', _T('Cannot display user "%s"', $uid).": ".$msg)
			if $msg;
	}

	unless ($servers{'ads'}{disable}) {
		$uid = get_attr($usr, 'uid');
		$cn = get_attr($usr, 'cn');
		$msg = ldap_obj_read($usr, 'ads', "(&(objectClass=user)(cn=$cn))");
		log_info('will create windows user "%s" for uid "%s"', $cn, $uid) if $msg;			
	}

	return $usr;
}


sub user_write ($)
{
	my $usr = shift;
	return unless $usr->{changed};
	my $msg;

	if ($config{debug}) {
		log_debug('-------- %s (changes) --------', get_attr($usr, 'dn'));
		for my $at (@{$usr->{attrs}}) {
			next if $at->{old} eq $at->{val};
			log_debug('changed %s (%s) -> (%s)', $at->{name}, $at->{old}, $at->{val});
		}
		log_debug('-' x 40);
	}

	$msg = ldap_obj_write($usr, 'uni');
	if ($msg) {
		message_box('error', 'close', _T('Error saving user "%s" (%s): %s',
					get_attr($usr, 'uid'), get_attr($usr, 'dn'), $msg));
	}

	$msg = ldap_obj_write($usr, 'ads');
	if ($msg) {
		message_box('error', 'close',
				_T('Error updating Windows-user "%s" (%s): %s',
					get_attr($usr, 'cn'), get_attr($usr, 'ntDn'), $msg));
	}

	my $home = get_attr($usr, 'homeDirectory');
	if ($config{create_homes} && $home ne '' && !(-d $home)) {
		log_info('creating home directory "%s"', $home);
		$install{src} = $config{skel_dir};
		$install{dst} = $home;
		$install{uidn} = get_attr($usr, 'uidNumber');
		$install{gidn} = ldap_get_unix_group_ids('uni',
											get_attr($usr, 'gidNumber'), 'warn');

		my $ret = File::Copy::Recursive::rcopy($install{src}, $install{dst});
		find(sub {
				# FIXME: is behaviour `lchown'-compatible ?
				chown $install{uidn}, $install{gidn}, $File::Find::name;
			}, $install{dst}
		);
	}

	return $usr;
}


sub ldap_obj_read ($$$)
{
	my ($obj, $srv, $filter) = @_;

	if ($servers{$srv}{disable}) {
		$obj->{ldap}{srv} = Net::LDAP::Entry->new;
		return undef;
	}

	my $res = ldap_search($srv, $filter, $obj->{attrlist}{$srv});
	if ($res->code || scalar($res->entries) == 0) {
		$obj->{ldap}{$srv} = Net::LDAP::Entry->new;
		return $res->error;
	}
	my $ldap = $obj->{ldap}{$srv} = $res->pop_entry;

	for my $at (@{$obj->{attrs}}) {
		next unless $at->{state} eq 'empty';
		my $name = $at->{desc}{ldap}{$srv};
		next unless $name;
		my $val = nvl( &{$at->{desc}{ldap_read}} ($at, $srv, $ldap, $name) );
		$at->{val} = $at->{old} = $val;
		$at->{state} = $val eq '' ? 'empty' : 'orig';
		$at->{entry}->set_text($at->{val}) if $at->{entry};
	}

	return 0;
}


sub ldap_obj_write ($$)
{
	my ($obj, $srv) = @_;
	return undef if $servers{$srv}{disable};
	my $ldap = $obj->{ldap}{$srv};
	my $changed = 0;
	my $msg;

	for my $at (@{$obj->{attrs}}) {
		my $name = $at->{desc}{ldap}{$srv};
		next unless $name;
		$changed |= &{$at->{desc}{ldap_write}} ($at, $srv, $ldap, $name, nvl($at->{val}));
	}

	if ($changed) {
		my $res = ldap_update($srv, $ldap);
		# Note: code 82 = `no values to update'
		$msg = $res->error if $res->code && $res->code != 82;
	}

	for my $at (@{$obj->{attrs}}) {
		my $name = $at->{desc}{ldap}{$srv};
		next unless $name;
		$changed |= &{$at->{desc}{ldap_write_final}} ($at, $srv, $ldap, $name, nvl($at->{val}));
	}

	return $msg;
}


# ========  reworking  ========


sub next_unix_uidn ()
{
	return $next_uidn if defined($next_uidn) && $next_uidn > 0;
	$next_uidn = 0;
	for (ldap_search('uni', '(objectClass=posixAccount)', [ 'uidNumber' ])->entries) {
		my $uidn = $_->get_value('uidNumber');
		$next_uidn = $uidn if $uidn > $next_uidn;
	}
	$next_uidn = $next_uidn > 0 ? $next_uidn + 1 : 1000;
	log_debug('next uidn: %d', $next_uidn);
	return $next_uidn;
}


sub next_unix_gidn ()
{
	return $next_gidn if defined($next_gidn) && $next_gidn > 0;
	$next_gidn = 0;
	for (ldap_search('uni', '(objectClass=posixGroup)', [ 'gidNumber' ])->entries) {
		my $gidn = $_->get_value('gidNumber');
		$next_gidn = $gidn if $gidn > $next_gidn;
	}
	$next_gidn = $next_gidn > 0 ? $next_gidn + 1 : 1000;
	log_debug('next gidn: %d', $next_gidn);
	return $next_gidn;
}


sub make_dn ($$)
{
	my ($obj, $what) = @_;
	my $dn = $config{$what};
	while ($dn =~ /\$\((\w+)\)/) {
		my $name = $1;
		my $val = get_attr($obj, $name);
		if ($val eq '') {
			$dn = '';
			last;
		}
		$dn =~ s/\$\($name\)/$val/g;
	}
	return $dn;
}


sub rework_accounts (@)
{
	my @ids = @_;
	#log_debug('rework ids: %s', join_list @ids);
	@ids = map { $_->get_value('uid') }
				ldap_search('uni', "(objectClass=person)", [ 'uid' ])->entries
		if $#ids < 0;
	for my $id (@ids) {
		log_debug('rework id %s ...', $id);
		my $usr = user_read(undef, $id);
		if ($usr) {
			rework_user($usr);
			$usr->{changed} = obj_changed($usr);
			user_write($usr);
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

	set_attr($usr, 'objectClass', append_list(get_attr($usr, 'objectClass'),
											$config{unix_user_classes}));

	cond_set($usr, 'dn', make_dn($usr, 'unix_user_dn'));
	cond_set($usr, 'ntDn', make_dn($usr, 'ad_user_dn'));

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

	############# Active Directory ############

	set_attr($usr, 'ntObjectClass', append_list(get_attr($usr, 'ntObjectClass'),
												$config{ad_user_classes}));

	cond_set($usr, 'objectCategory', join(',',path2dn($config{ad_user_category}),
											path2dn($config{ad_domain},'dc')));

	my %path_subst = (SERVER => $config{home_server}, USER => $uid);

	cond_set($usr, 'ntUserHomeDir',
			ifnull($uid, subst_path($config{ad_home_dir}, %path_subst)));

	cond_set($usr, 'ntUserProfile',
			ifnull($uid, subst_path($config{ad_profile_path}, %path_subst)));

	cond_set($usr, 'ntUserScriptPath',
			ifnull($uid, subst_path($config{ad_script_path}, %path_subst)));

	cond_set($usr, 'userPrincipalName', $uid.'@'.$config{ad_domain});	

	my $pass = get_attr($usr, 'password');
	if ($pass eq OLD_PASS) {
		set_attr($usr, 'userAccountControl',
				get_attr($usr, 'userAccountControl', orig => 1));
	} else {
		my $uac = get_attr($usr, 'userAccountControl');
		$uac = ADS_UF_NORMAL_ACCOUNT unless $uac;
		$uac &= ~(ADS_UF_PASSWD_NOT_REQUIRED | ADS_UF_DONT_EXPIRE_PASSWD);
		$uac |= $pass eq '' ? ADS_UF_PASSWD_NOT_REQUIRED : ADS_UF_DONT_EXPIRE_PASSWD;
		set_attr($usr, 'userAccountControl', $uac);
	}

	###### constant and copy-from fields ########
	for my $at (@{$usr->{attrs}}) {
		my $desc = $at->{desc};
		cond_set($usr, $at->{name}, $desc->{default})
			if defined $desc->{default};
		cond_set($usr, $at->{name}, get_attr($usr, $desc->{copyfrom}))
			if $desc->{copyfrom};
	}
}


# NOTE: structure of this routine is correct
#       user reworking routines shouls work the same way
sub rework_group ($)
{
	my $grp = shift;

	set_attr($grp, 'objectClass', $config{unix_group_classes});

	my $val = get_attr($grp, 'cn');
	set_attr($grp, 'cn', string2id($val));

	$val = get_attr($grp, 'gidNumber');
	$val = next_unix_gidn() unless $val;
	$val =~ tr/0123456789//cd;
	set_attr($grp, 'gidNumber', $val);

	set_attr($grp, 'dn', make_dn($grp, 'unix_group_dn'));
}


# ======== connections ========


sub get_server ($;$)
{
	my ($srv, $active) = @_;
	my $cfg = $servers{$srv};
	log_error('unknown ldap server "%s"', $srv) unless $cfg;
	log_error('server "%s" is disabled', $srv) if $active && $cfg->{disable};
	return $cfg;
}


sub ldap_search ($$;$@)
{
	my ($srv, $filter, $attrs, %params) = @_;
	my $cfg = get_server($srv,1);
	$params{filter} = $filter;
	$params{base} = $cfg->{base} unless $params{base};
	$params{attrs} = $attrs if $attrs;
	return $cfg->{ldap}->search(%params);
}


sub ldap_update ($$)
{
	my ($srv, $ent) = @_;
	$next_uidn = $next_gidn = undef;
	return $ent->update(get_server($srv,1)->{ldap});
}


sub ldap_delete ($$)
{
	my ($srv, $ent) = @_;
	return get_server($srv,1)->{ldap}->delete($ent);
}


sub ldap_connect_all ()
{
	for my $srv (keys %servers) {
		my $cfg = $servers{$srv};
		my ($ldap, $mesg, $entry);
		$cfg->{name} = $srv;

		if ($cfg->{disable}) {
			$cfg->{ldap} = Net::LDAP->new;
			next;
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

		log_error('invalid credentials for ldap server "%s"', $srv)
			unless $uri && $user && $pass;
 
		$ldap = Net::LDAP->new($uri, debug => $cfg->{debug})
			or log_error('cannot connect to %s: %s', $uri, $@);
		$mesg = $ldap->bind($user, password => $pass);
		log_error('cannot bind to ldap server "%s": %s', $srv, $mesg->error)
			if $mesg->code;
		$cfg->{ldap} = $ldap;
	}
}


sub ldap_disconnect_all ()
{
	for my $cfg (values %servers) {
		next if $cfg->{disable};
		$cfg->{ldap}->disconnect;
	}
}


# ======== user gui =========


sub update_obj_gui ($)
{
	my $obj = shift;
	for my $at (@{$obj->{attrs}}) {
		my $entry = $at->{entry};
		if ($entry && nvl($at->{val}) ne nvl($entry->get_text)) {
			my $pos = $entry->get_position;
			$entry->set_text($at->{val});
			$entry->set_position($pos);
		}
		if (defined $at->{bulb}) {
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


sub user_save ()
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

	user_load();
	set_user_changed(0);
	$btn_usr_add->set_sensitive(1);
}


sub user_revert ()
{
	my $resp = message_box('question', 'yes-no', _T('Really revert changes ?'));
	return if $resp ne 'yes';
	set_user_changed(0);
	$btn_usr_add->set_sensitive(1);
	user_load();
}


sub user_add ()
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
	get_attr_node($usr, $gui_attrs{user}[0][1])->{entry}->grab_focus;
	set_user_changed(0);
	$btn_usr_add->set_sensitive(0);
	user_load();
}


sub user_delete ()
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

		rework_user($usr);	# produce dn and ntDn
		my $dn = get_attr($usr, 'dn');
		my $ntDn = get_attr($usr, 'ntDn');

		my $res = ldap_delete('uni', $dn);
		if ($res->code) {
			message_box('error', 'close',
					_T('Error deleting Unix-user "%s" (%s): %s', $uid, $dn, $res->error));
			return;
		}

		my $gid_list = get_attr($usr, 'moreGroups', orig => 1);
		$gid_list = append_list($gid_list, get_attr($usr, 'gidNumber'));
		my $uidn = get_attr($usr, 'uidNumber');
		for my $gidn (ldap_get_unix_group_ids('uni', $gid_list, 'nowarn')) {
			ldap_modify_unix_group('uni', $gidn, $uidn, 'remove');
		}

		unless ($servers{'ads'}{disable}) {
			$res = ldap_delete('ads', $ntDn);
			if ($res->code) {
				message_box('error', 'close',
					_T('Error deleting Windows-user "%s" (%s): %s', $uid, $ntDn, $res->error));
			}
		}

		my $home = get_attr($usr, 'homeDirectory');
		if ($config{remove_homes} && $home ne '') {
			system "/bin/rm -rf \"$home\"";
		}
	}

	$model->remove($node);
	set_user_changed(0);
	$btn_usr_add->set_sensitive(1);

	if ($path->prev || $path->next) {
		$list->set_cursor($path);
		user_load();
	} else {
		user_unselect();
	}
}


sub users_refresh ()
{
	user_unselect();
	rework_accounts();

	my @attrs = ('uid', 'cn');
	my $model = $user_list->get_model;
	$model->clear;

	my $res = ldap_search('uni', "(objectClass=person)", \@attrs);
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


sub user_change ()
{
	my ($path, $column) = $user_list->get_cursor;
	my $model = $user_list->get_model;
	if (defined $path) {
		my $node = $model->get_iter($path);
		$model->remove($node) if is_new_user($node);
		$btn_usr_add->set_sensitive(1);
	}
}


sub user_unselect ()
{
	# exit if interface is not built complete
	return unless defined $user_name;
	my $usr = $user_obj;
	clear_obj($usr);
	$user_name->set_text('');
	for ($btn_usr_apply, $btn_usr_revert, $btn_usr_delete) { $_->set_sensitive(0); }
	$user_attr_tabs->set_current_page(0);
	$user_attr_frame->set_sensitive(0);
	return 0;
}


sub user_load ()
{
	my ($path, $column) = $user_list->get_cursor;
	return unless defined $path;

	my $model = $user_list->get_model;
	my $node = $model->get_iter($path);
	my ($uid, $cn) = map {$model->get($node, $_)} (0,1);
	return unless defined $uid;

	my $usr = $user_obj;
	clear_obj($usr);
	user_read($usr, $uid) unless is_new_user($node);
	update_obj_gui($usr);

	$user_name->set_text("$uid ($cn)");
	$btn_usr_delete->set_sensitive(1);
	$user_attr_tabs->set_current_page(0);
	$user_attr_frame->set_sensitive(1);
}


sub user_entry_edited ($)
{
	my $at = shift;
	my $usr = $at->{obj};
	my $val = nvl($at->{entry}->get_text);
	return if $val eq $at->{val};
	set_attr($usr, $at->{name}, $val);
	rework_user($usr);
	update_obj_gui($usr);
	set_user_changed(obj_changed($usr));
	my $username = sprintf '%s (%s)', get_attr($usr, 'uid'), get_attr($usr, 'cn');
	$user_name->set_text($username) if $user_name->get_text ne $username;
}


sub set_user_changed ($)
{
	my $chg = shift;
	my $usr = $user_obj;
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
	my $usr = $at->{obj};
	my $val = nvl($at->{entry}->get_text);
	$val = $active ? append_list($val,$uid) : remove_list($val,$uid);
	set_attr($usr, $at->{name}, $val);
	update_obj_gui($usr);
	set_user_changed(obj_changed($usr));
}


sub create_user_groups_editor ($)
{
	my $at = shift;
	my $popup_btn = $at->{popup};

	my $res = ldap_search('uni', "(objectClass=posixGroup)", ['cn']);
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


sub user_group_selected ($$)
{
	my ($at, $list) = @_;
	my ($path, $column) = $list->get_cursor;
	my $model = $list->get_model;
	my $node = $model->get_iter($path);
	my $usr = $at->{obj};
	set_attr($usr, $at->{name}, $model->get($node, 0));
	update_obj_gui($usr);
	set_user_changed(obj_changed($usr));
}


sub create_group_chooser ($)
{
	my $at = shift;
	my $popup_btn = $at->{popup};

	my $res = ldap_search('uni', "(objectClass=posixGroup)", [ 'cn', 'gidNumber' ]);
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


sub create_user_desc ()
{
	my $vbox = Gtk2::VBox->new(0, 0);
	my $frame;

	my $usr = $user_obj = create_obj('user');
	set_attr($usr, 'objectClass', '');

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

	for (@{$gui_attrs{user}}) {
		my ($tab_name, @tab_attrs) = @$_;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, _T($tab_name));
		$scroll->set_policy('automatic', 'automatic');
		$scroll->set_border_width(0);

		my $abox = Gtk2::Table->new($#tab_attrs + 1, 4);
		$scroll->add_with_viewport($abox);

		for my $r (0 .. $#tab_attrs) {
			my $at = init_attr($usr, $tab_attrs[$r], 2);
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
			$at->{entry}->signal_connect(key_release_event => sub { user_entry_edited($at) })
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


sub create_user_list ()
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

	$user_list->signal_connect(cursor_changed => \&user_load);
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


sub group_save ()
{
	my ($path, $column) = $group_list->get_cursor;
	return unless defined $path;
	my $grp = $group_obj;
	return unless $grp->{changed};

	my $model = $group_list->get_model;
	my $node = $model->get_iter($path);
	my $gid = get_attr($grp, 'cn');
	$model->set($node, 0, $gid);

	$grp->{changed} = obj_changed($grp);
	my $msg = ldap_obj_write($grp, 'uni');
	if ($msg) {
		message_box('error', 'close', _T('Error saving group "%s": %s', $gid, $msg));
		return undef;
	}

	group_load();
	set_group_changed(0);
	$btn_grp_add->set_sensitive(1);
}


sub group_revert ()
{
	my $resp = message_box('question', 'yes-no', _T('Really revert changes ?'));
	return if $resp ne 'yes';
	set_group_changed(0);
	$btn_grp_add->set_sensitive(1);
	group_load();
}


sub group_add ()
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

	get_attr_node($grp, $gui_attrs{group}[0][1])->{entry}->grab_focus;
	set_group_changed(0);
	$btn_grp_add->set_sensitive(0);

	group_load();
}


sub group_delete ()
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

		my $res = ldap_delete('uni', get_attr($grp, 'dn'));
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
		group_load();
	} else {
		group_unselect();
	}
}


sub groups_refresh ()
{
	group_unselect();

	my $model = $group_list->get_model;
	$model->clear;

	my $res = ldap_search('uni', '(objectClass=posixGroup)', ['cn']);
	my @groups = $res->entries;
	@groups = sort { $a->get_value('cn') cmp $b->get_value('cn') } @groups;

	for my $entry (@groups) {
		my $node = $model->append(undef);
		$model->set($node, 0, nvl($entry->get_value('cn')));
	}

	$btn_grp_add->set_sensitive(1) if defined $btn_grp_add;
}


sub group_change ()
{
	my ($path, $column) = $group_list->get_cursor;
	my $model = $group_list->get_model;
	if (defined $path) {
		my $node = $model->get_iter($path);
		$model->remove($node) if is_new_group($node);
		$btn_grp_add->set_sensitive(1);
	}
}


sub group_unselect ()
{
	# exit if interface is not built complete
	return unless defined $group_name;
	my $grp = $group_obj;
	clear_obj($grp);
	$group_name->set_text('');
	for ($btn_grp_apply, $btn_grp_revert, $btn_grp_delete) { $_->set_sensitive(0) }
	$group_attr_frame->set_sensitive(0);
	return 0;
}


sub group_load ()
{
	my ($path, $column) = $group_list->get_cursor;
	return unless defined $path;

	my $model = $group_list->get_model;
	my $node = $model->get_iter($path);
	my $gid = $model->get($node, 0);
	return unless defined $gid;

	my $grp = $group_obj;
	clear_obj($grp);

	unless (is_new_group($node)) {
		my $msg = ldap_obj_read($grp, 'uni', "(&(objectClass=posixGroup)(cn=$gid))");
		message_box('error', 'close', _T('Cannot display group "%s"', $gid).": ".$msg)
			if $msg;
	}

	update_obj_gui($grp);
	$group_name->set_text($gid);
	$btn_grp_delete->set_sensitive(1);
	$group_attr_frame->set_sensitive(1);
}


sub group_entry_edited ($)
{
	my $at = shift;
	my $grp = $at->{obj};

	my $val = nvl($at->{entry}->get_text);
	return if $val eq $at->{val};

	set_attr($grp, $at->{name}, $val);
	rework_group($grp);
	$group_name->set_text(get_attr($grp, 'cn'));
	set_group_changed(obj_changed($grp));
}


sub set_group_changed ($)
{
	my $chg = shift;
	my $grp = $group_obj;
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
	my $grp = $at->{obj};
	my $val = nvl($at->{entry}->get_text);
	$val = $active ? append_list($val,$uid) : remove_list($val,$uid);
	set_attr($grp, $at->{name}, $val);
	update_obj_gui($grp);
	set_group_changed(obj_changed($grp));
}


sub create_group_users_editor ($)
{
	my $at = shift;
	my $popup_btn = $at->{popup};

	my $res = ldap_search('uni', "(objectClass=person)", ['uid']);
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


sub create_group_desc ()
{
	my $vbox = Gtk2::VBox->new(0, 0);
	my $frame;

	my $grp = $group_obj = create_obj('group');
	set_attr($grp, 'objectClass', '');

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

	for (@{$gui_attrs{group}}) {
		my ($tab_name, @tab_attrs) = @$_;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, _T($tab_name));
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
			$at->{entry}->signal_connect(key_release_event => sub { group_entry_edited($at) });
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


sub create_group_list ()
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

	$group_list->signal_connect(cursor_changed => \&group_load);
	$group_list->signal_connect(move_cursor => \&group_change);

	return $frame;
}


# ======== main ========


sub gui_exit ()
{
	if ($user_obj->{changed} || $group_obj->{changed}) {
		my $resp = message_box('question', 'yes-no', _T('Exit and loose changes ?'));
		return 1 if $resp ne 'yes';
		$user_obj->{changed} = $group_obj->{changed} = 0;
	}
	user_unselect();
	group_unselect();
	ldap_disconnect_all();
	Gtk2->main_quit;
}


sub gui_main ()
{
	($pname = $0) =~ s/^.*\///;
	my %opts;
	my $cmd_ok = getopts("Dhd", \%opts);

	my $fh = select(STDOUT); $| = 1; select($fh);
	log_error('usage: $pname [-d] [-D]') if !$cmd_ok || $opts{h};

	configure(@{$config{config_files}});
	dump_config() if $opts{D};
	$config{debug} = 1 if $opts{d};

	ldap_connect_all();
	setup_attrs();

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
		[ undef, "userman_32x32.png", 'pic' ],
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
		[ undef, "userman_32x32.png", 'pic' ],
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
}


gui_main();
