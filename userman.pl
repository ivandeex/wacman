#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use strict;
use warnings;
use utf8;
use Carp qw(cluck croak);
use Getopt::Std;
use Gtk2;
use POSIX;
use Encode;
use Time::HiRes 'gettimeofday';
use Net::LDAP;
use Net::LDAP::Entry;
use File::Find;
use File::Copy::Recursive;

use FindBin qw[$Bin];
use Cwd 'abs_path';

my ($srv, $win, $pname, $main_wnd, %install);

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


sub _T
{
	my ($fmt, @args) = @_;
	$fmt = $translations{$fmt} if defined $translations{$fmt};
	my $ret = sprintf($fmt, @args);
	return $ret;
}


# ======== config =========


use constant NO_EXPIRE => '9223372036854775807';
use constant SAM_USER_OBJECT => hex('0x30000000');
use constant ADS_UF_NORMAL_ACCOUNT => hex(0x00000200);


my %servers = (
	win => {
		uri		=>	'ldaps://xxx.winsrv.vpn',
		user	=>	'cn=dirman,dc=gclimate,dc=local',
		passfile=>	'/etc/ldap-gui.secret',
		base	=>	'dc=gclimate,dc=local',
		debug	=>	0,
		convert	=>	0,
		disabled=>	0,
	},
	srv => {
		uri		=>	'ldaps://xxx.el4.vihens.ru',
		user	=>	'cn=dirman,dc=vihens,dc=ru',
		passfile=>	'/etc/ldap-gui.secret',
		base	=>	'dc=vihens,dc=ru',
		debug	=>	0,
		convert	=>	1,
		disabled=>	0,
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
	'User#'			=>	'# пользователя',
	'Group#'		=>	'# группы',
	'Other groups'	=>	'Прочие группы',
	'Home directory'=>	'Домашний каталог',
	'Login shell'	=>	'Интерпретатор команд',
	'Drive'			=>	'Диск',
	'Profile'		=>	'Профиль',
	'Logon script'	=>	'Сценарий входа',
	'Telephone'		=>	'Телефон',
	'Fax number'	=>	'Номер факса',
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
);


my %config = (
	debug				=>	0,
	nodirs				=>	0,
	config_files		=>	[
			'/etc/ldap-gui.cfg',
			'~/.ldap-gui.cfg',
			'./ldap-gui.cfg'
		],
	skel_dir			=>	'/etc/skel',
	xinstall_command	=>	'/usr/bin/sudo -S /usr/local/sbin/xinstall',
	unix_user_dn		=>	'uid=[uid],ou=People,dc=vihens,dc=ru',
	unix_group_dn		=>	'cn=[cn],ou=Groups,dc=vihens,dc=ru',

	ad_initial_pass		=>	'123qweASD',
	unix_user_classes	=>	[
			qw(top person organizationalPerson inetOrgPerson posixAccount shadowAccount ntUser)
		],	
	unix_group_classes	=>	[ qw(top posixGroup) ],	
	ad_user_classes		=>	[ qw(top user person organizationalPerson) ],	
	ad_user_category	=>	'Person.Schema.Configuration',
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


my %unix_fields_const = (
	loginShell => '/bin/bash',
	ntUserCreateNewAccount => 'false',
	ntUserDeleteAccount => 'false',
	ntUserHomeDirDrive => 'H',
	ntUserAcctExpires => NO_EXPIRE,
	gidNumber => 100,
	telephoneNumber => '',
	facsimileTelephoneNumber => '',
);


my %ad_fields_from_unix = (
	#'cn' => 'uid',
	'displayName' => 'cn',
	'givenName' => 'givenName',
	#'name' => 'cn',
	'sAMAccountName' => 'uid',
	'sn' => 'sn',
	#'userPrincipalName' => 'mail',
	'uid' => 'uid',
	'mail' => 'mail',
	'uidNumber' => 'uidNumber',
	'gidNumber' => 'gidNumber',
	'unixHomeDirectory' => 'homeDirectory',
	'unixUserPassword' => 'userPassword',
	'loginShell' => 'loginShell',
	'o' => 'o',
	'ou' => 'ou',
	'title' => 'title',
	'physicalDeliveryOfficeName' => '',
	'telephoneNumber' => '',
	'facsimileTelephoneNumber' => '',
	'homeDirectory' => 'ntUserHomeDir',
	'homeDrive' => 'ntUserHomeDirDrive',
	'profilePath' => 'ntUserProfile',
	'scriptPath' => 'ntUserScriptPath',
);


my %ad_fields_const = (
	accountExpires => NO_EXPIRE,
	#codePage => pack('c',0),
	#countryCode => '0',
	#instanceType => '4',
	#logonCount => '0',
	#pwdLastSet => '0',
	#sAMAccountType => SAM_USER_OBJECT,
);


my @user_gui_attrs = (
	[ 'UNIX',
		[ 's', 'givenName', _T('Name') ],
		[ 's', 'sn', _T('Second name') ],
		[ 's', 'cn', _T('Full name') ],
		[ 'd', 'uid', _T('Identifier') ],
		[ 's', 'mail', _T('Mail') ],
		[ 's', 'uidNumber', _T('User#') ],
		[ 'g', 'gidNumber', _T('Group#') ],
		[ 'G', 'other groups', _T('Other groups') ],
		[ 's', 'homeDirectory', _T('Home directory') ],
		[ 's', 'loginShell', _T('Login shell') ],
	],
	[ 'Windows',
		[ 's', 'ntUserHomeDir', _T('Home directory') ],
		[ 's', 'ntUserHomeDirDrive', _T('Drive') ],
		[ 's', 'ntUserProfile', _T('Profile') ],
		[ 's', 'ntUserScriptPath', _T('Logon script') ]
	],
	[ 'Дополнительно',
		[ 's', 'telephoneNumber', _T('Telephone') ],
		[ 's', 'facsimileTelephoneNumber', _T('Fax number') ],
	],
);


my @group_gui_attrs = (
	[ 'POSIX',
		[ 's', 'cn', _T('Group name') ],
		[ 's', 'gidNumber', _T('Group number') ],
		[ 's', 'description', _T('Description') ],
		[ 'U', 'memberUid', _T('Members') ],
	],
);


my %state2pic = (
	'user'  => 'yellow.png',
	'orig'  => 'green.png',
	'calc'  => 'blue.png',
	'empty' => 'empty.png',
);


# ======== configuring ========


sub configure
{
	for my $file (@_) {
		next unless $file;
		$file =~ s/^~\//$ENV{HOME}\//;
		next unless -r $file;
		open(CONFIG, "$file") or next;
		my $mode = "config";
		my %modes = ( win => 1, srv => 1, config => 1 );
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
				if (($mode eq "win") || ($mode eq "srv")) {
					$servers{$mode}->{$name} = $val;
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
	for (sort keys %{$servers{srv}}) { print "srv{$_} = \"$servers{srv}->{$_}\"\n"; }
	for (sort keys %{$servers{win}}) { print "win{$_} = \"$servers{win}->{$_}\"\n"; }
	for (sort keys %config) {
		my $val = $config{$_};
		$val = ($val =~ /^ARRAY\(\S+\)$/)
					? '[ '.join(', ',map("\"$_\"",@$val)).' ]' : "\"$val\"";
		print "config{$_} = $val\n";
	}
}


# ======= Visualization =========


use constant SECS1610TO1970 => 11644473600;

my $HR = "=" x 48;

my %convtype2subs = (
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
	'wintime'	=> [
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

my %atrname2convtype = (
	'ufn'				=> 'bkslash',
	'objectSid'			=> 'binary',
	'objectGuid'		=> 'binary',
	'userAccountControl'=> 'decihex',
	'samAccountType'	=> 'decihex',
	'systemFlags'		=> 'decihex',
	'groupType'			=> 'decihex',
	'whenCreated'		=> 'monotime',
	'whenChanged'		=> 'monotime',
	'accountExpires'	=> 'wintime',
	'pwdLastSet'		=> 'wintime',
	'ntUserLastLogon'	=> 'wintime',
	'ntUserAcctExpires' => 'wintime',
	'badPasswordTime'	=> 'wintime',
	'lastLogon'			=> 'wintime',
	'lastLogoff'		=> 'wintime',
	'logonHours'		=> 'binary',
	'userParameters'	=> 'binary',
);

for my $key (keys(%atrname2convtype)) {
	my $low = $key;
	$low =~ tr/[A-Z]/[a-z]/;
	$atrname2convtype{$low} = $atrname2convtype{$key};
}


sub ldap_convert_attr ($$$)
{
	my ($attr, $value, $dir) = @_;
	$attr =~ tr/[A-Z]/[a-z]/;
	if (defined($atrname2convtype{$attr})
			&& defined($convtype2subs{$atrname2convtype{$attr}})) {
		my $sub = $convtype2subs{$atrname2convtype{$attr}}->[$dir];
		return &$sub($value) if defined $sub;
	}
	return $value;
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
	croak($str) if $level eq 'error';
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
	my ($text, $pic, $action, $owner_box) = @_;
	my $button = Gtk2::Button->new;
	my $hbox = Gtk2::HBox->new;
	$hbox->set_name('hbox');
	$button->add($hbox);
	my $image = Gtk2::Image->new;
	$image->set_name('image');
	$hbox->pack_start($image, 0, 0, 1);
	my $label = Gtk2::Label->new;
	$label->set_name('text');
	$hbox->pack_end($label, 0, 0, 1);
	$label->set_text($text) if $text;
	set_button_image($button, $pic) if $pic;		
	$button->signal_connect("clicked" => $action) if $action;
	$owner_box->pack_start($button, 0, 0, 1) if $owner_box;
	return $button;
}


sub set_button_image ($$)
{
	my ($button, $pic) = @_;
	$button->foreach(sub {
		my $hb = shift;
		return if $hb->get_name ne 'hbox';
		$hb->foreach(sub {
			my $im = shift;
			return if $im->get_name ne 'image';
			if ($pic) {
				$im->set_from_pixbuf(create_pic($pic));
			} else {
				$im->clear;
			}
		});
	});
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
		my $button = create_button($label, $pic, $action);
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
	return split(/\s*\;\s*/, $s);
}


sub join_list (@)
{
	return join(';', @_);
}


# ========  rework helpers  ========


sub next_unix_uidn
{
	if (defined($next_uidn) && $next_uidn > 0) {
		return $next_uidn;
	}
	$next_uidn = 0;
	my $res = ldap_search($srv, '(objectClass=posixAccount)', [ 'uidNumber' ]);
	for ($res->entries) {
		my $uidn = $_->get_value('uidNumber');
		$next_uidn = $uidn if $uidn > $next_uidn;
	}
	$next_uidn = $next_uidn > 0 ? $next_uidn + 1 : 1000;
	log_debug('next uidn: %d', $next_uidn);
	return $next_uidn;
}


sub next_unix_gidn
{
	if (defined($next_gidn) && $next_gidn > 0) {
		return $next_gidn;
	}
	$next_gidn = 0;
	my $res = ldap_search($srv, '(objectClass=posixGroup)', [ 'gidNumber' ]);
	for ($res->entries) {
		my $gidn = $_->get_value('gidNumber');
		$next_gidn = $gidn if $gidn > $next_gidn;
	}
	$next_gidn = $next_gidn > 0 ? $next_gidn + 1 : 1000;
	log_debug('next gidn: %d', $next_gidn);
	return $next_gidn;
}


sub unix_user_dn ($)
{
	my $uo = shift;
	my $dn = $config{unix_user_dn};
	my $uid = get_attr($uo, 'uid');
	return undef unless $uid;
	my $cn = get_attr($uo, 'cn');
	$dn =~ s/\[uid\]/$uid/g;
	$dn =~ s/\[cn\]/$uid/g;
	return $dn;
}


my %state2has = (
	force => 0,
	user => 1,
	empty => 0,
	orig => 1,
	calc => 0,
);


sub has_attr ($$)
{
	my ($obj, $attr) = @_;

	$obj->{a} = {} unless defined $obj->{a};

	my $a = $obj->{a}->{$attr};
	return 0 unless defined $a;

	my $state = nvl($a->{state});
	return $state2has{$state} if defined $state2has{$state};

	return nvl($a->{cur}) ne '' ? 1 : 0;
}


sub get_attr ($$)
{
	my ($obj, $attr) = @_;
	$obj->{a} = {} unless defined $obj->{a};
	my $a = $obj->{a}->{$attr};
	cluck "wow" if defined($a) && $a eq 'winadmin';
	return defined($a) ? nvl($a->{cur}) : '';
}


sub set_attr ($$$)
{
	my ($obj, $attr, $val) = @_;

	my $sdn = nvl($obj->{dn});
	$sdn = ($sdn =~ /^\s*(.*?)\s*,/) ? $1 : '???';

	if (defined($obj->{a}) && defined($obj->{a}->{$attr})) {
		my $a = $obj->{a}->{$attr};
		if ($attr eq 'objectClass') {
			my ($c, %ca);
			my @ca = split_list(nvl($a->{cur}));
			for $c (@ca) { $ca{lc($c)} = 1 }
			for $c (split_list($val)) { push(@ca, $c) unless $ca{lc($c)} } 
			$a->{val} = join_list(sort(@ca));
		} else {
			$a->{val} = $val;
		}
		log_debug('(%s): [%s] := (%s)', $sdn, $attr, $val)
			if $a->{orig} ne $a->{val};
	} else {
		my $a = {
			parent => $obj,
			attr => $attr,
			visual => 0,
			type => 's',
		};
 		$a->{orig} = $a->{cur} = '';
		$a->{val} = $a->{usr} = $val;
		$obj->{a}->{$attr} = $a;
		log_debug('(%s): [%s] += (%s)', $sdn, $attr, $val)
	}
}


sub cond_set ($$$)
{
	my ($obj, $attr, $val) = @_;
	my $has = has_attr($obj, $attr);
	set_attr($obj, $attr, $val) unless $has;
	return $has;
}


sub set_ldap_attr ($)
{
	my $a = shift;
	my ($ldap, $attr, $type) = ($a->{parent}->{ldap}, $a->{attr}, $a->{type});
	my $val = defined($a->{cur}) ? nvl($a->{cur}) : '';
	my $changed = 0;
	if ($attr eq 'objectClass') {
		my ($c, %ca);
		for $c ($ldap->get_value('objectClass')) { $ca{lc($c)} = 1 }
		for $c (split_list $val) {
			next if defined $ca{lc($c)};
			$ldap->add(objectClass => $c);
			$changed = 1;
		}
		return $changed;
	}
	if ($type eq 'U') {
		# list of users
		my @uidns = ();
		for my $uid (split_list $val) {
			if ($uid =~ /^\d+/) {
				push(@uidns, $uid);
				next;
			}
			my $res = ldap_search($srv, "(&(objectClass=person)(uid=$uid))", [ 'uidNumber' ]);
			my $ue = $res->pop_entry;
			my $uidn = $ue ? $ue->get_value('uidNumber') : -1;
			log_debug('search for uid="%s" returns uidn=%d (code=%d)',
					$uid, $uidn, $res->code);
			if ($uidn != -1) {
				push(@uidns, $uidn);
			} else {
				log_info('did not find user uid "%s"', $uid);
			}
		}
		log_debug('set_ldap_attr: uidns "%s"; "%s" => [%s]',
				$attr, $val, join(',', @uidns));
		if ($#uidns < 0) {
			$ldap->delete($attr);
		} elsif ($ldap->exists($attr)) {
			$ldap->replace($attr => \@uidns);
		} else {
			$ldap->add($attr => \@uidns);			
		}
		return 1;
	}
	if ($type eq 'g') {
		# group ID
		if ($val !~ /^\d*$/) {
			my $cn = $val;
			$val = 0;
			my $res = ldap_search($srv, '(&(objectClass=posixGroup)(cn=$cn))', ['gidNumber']);
			my $grp = $res->pop_entry;
			if ($grp) {
				my $gidn = $grp->get_value('gidNumber');
				$val = $gidn if $gidn;
			}
			unless ($val) {
				log_info('set_ldap_attr: group "%s" not found', $cn);
			}
		}
	}
	if ($type ne 's' && $type ne 'd') {
		log_debug('set_ldap_attr: "%s" is a special attr of type "%s"...', $attr, $type);
		return 0;
	}
	# simple attributes: 's' and 'd
	if ($val eq '') {
		if ($ldap->exists($attr)) {
			$ldap->delete($attr);
			$changed = 1;
		}
	} elsif ($ldap->exists($attr)) {
		if ($ldap->get_value($attr) ne $val) {
			$ldap->replace($attr => $val);
			$changed = 1;
		}
	} else {
		$ldap->add($attr => $val);
		$changed = 1;
	}
	return $changed;
}


sub get_ldap_attr ($)
{
	my $a = shift;
	my ($ldap, $attr, $type) = ($a->{parent}->{ldap}, $a->{attr}, $a->{type});
	my $val;
	if ($attr eq 'objectClass') {
		$val = join_list(sort($ldap->get_value('objectClass')));
	} elsif ($type eq 's' || $type eq 'd') {
		# normal string or number
		$val = nvl($ldap->get_value($a->{attr}));
	} elsif ($type eq 'g') {
		# group ID
		$val = nvl($ldap->get_value($a->{attr}));
		if ($val =~ /^\d+$/) {
			log_debug('search for group id %d', $val);
			my $res = ldap_search($srv, "(&(objectClass=posixGroup)(gidNumber=$val))");
			my $grp = $res->pop_entry;
			if ($grp) {
				my $cn = $grp->get_value('cn');
				$val = $cn if $cn;
			} else {
				log_debug('cannot find group id %d (error: %s)', $val, $res->error);
			}
		}
	} elsif ($type eq 'U') {
		# list of users
		my @uidns = $ldap->get_value($a->{attr});
		log_debug('get_ldap_attr: "%s"/%s is (%s)', $attr, $type, join(',', @uidns));
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
		$val = join_list @uids;
		log_debug('get_ldap_attr: "%s"/%s returns "%s"...', $attr, $type, $val);
	} else {
		# special attributes
		log_debug('get_ldap_attr: "%s" is a special attr of type "%s"...', $attr, $type);
		$val = '';
	}
	$a->{val} = $a->{cur} = $a->{orig} = $a->{usr} = $val;
	$a->{state} = $val eq '' ? 'empty' : 'orig';
	return $a;
}


sub set_ldap_attr_final ($)
{
	my $a = shift;
	my ($attr, $type) = ($a->{attr}, $a->{type});
	my $val = defined($a->{cur}) ? nvl($a->{cur}) : '';
	log_debug('attr "%s" is undefined type', $attr) unless defined $type;
	return if $type eq 's' || $type eq 'g' || $type eq 'd';
	log_debug('set_ldap_attr_final: "%s" is a special attr of type "%s"...', $attr, $a->{type});
	return 0;
}


# ========  reworking  ========


sub rework_accounts
{
	my @ids = @_;
	log_debug('rework ids: %s', join(',', @ids));
	if ($#ids < 0) {
		my $res = ldap_search($srv, "(objectClass=person)", [ 'uid' ]);
		# get all users
		@ids = map { $_->get_value('uid') } $res->entries;
	}
	for my $id (@ids) {
		log_debug('rework id %s ...', $id);
		my $usr = rework_unix_account($id);
		if ($usr) {
			log_debug('continue reworking (nodirs=%s)', $config{nodirs});
			rework_home_dir($usr) unless $config{nodirs};
			rework_windows_account($usr) unless $win->{cfg}->{disabled};
		}
	}
}


sub rework_unix_account
{
	my $id = shift;
	my $usr = {};
	my $res = ldap_search($srv, "(&(objectClass=person)(uid=$id))");
	if ($res->code) {
		message_box('error', 'close', _T('User "%s" not found: %s',$id,$res->error));
		return undef;
	}
	$usr->{ldap} = $res->pop_entry;
	unless (defined $usr->{ldap}) {
		message_box('error', 'close', _T('User "%s" not found',$id));
		return undef;
	}
	$usr->{changed} = 0;

	$usr->{dn} = $usr->{ldap}->dn;
	my $a;
	for my $attr ($usr->{ldap}->attributes(nooptions => 1), 'objectClass') {
		my $type = 's';
		$a = {
			parent => $usr,
			visual => 0,
			type => $type,
			attr => $attr,
		};
		get_ldap_attr($a);
		$usr->{a}->{$attr} = $a;
	}

	rework_unix_account_entry($usr);

	for $a (values %{$usr->{a}}) {
		$a->{cur} = $a->{val};
		$usr->{changed} = 1 if $a->{cur} ne $a->{orig};
	}

	# dn
	$usr->{dn} = unix_user_dn($usr)
		if nvl($usr->{dn}) eq '';

	if ($usr->{changed}) {
		$usr->{dn} = unix_user_dn($usr) unless $usr->{dn};
		for $a (values %{$usr->{a}}) { set_ldap_attr($a); }
		$usr->{ldap}->dn($usr->{dn});
		$res = ldap_update($srv, $usr->{ldap});
		log_info('error updating user "%s" (%s): %s',
				get_attr($usr, 'uid'), $usr->{ldap}->dn, $res->error) if $res->code;
	}

	return $usr;
}


sub rework_unix_account_entry ($)
{
	my $usr = shift;

	# read all scalar attributes
	my $uid = get_attr($usr, 'uid');
	my $cn = get_attr($usr, 'cn');
	my $gn = get_attr($usr, 'givenName');
	my $sn = get_attr($usr, 'sn');

	# name
	cond_set($usr, 'cn', $cn = $gn . ($sn && $gn ? ' ' : '') . $sn)
		unless has_attr($usr, 'cn');

	# identifier
	$uid = $sn eq '' ? $gn : substr($gn, 0, 1) . $sn
		unless has_attr($usr, 'uid');
	set_attr($usr, 'uid', $uid = string2id($uid));

	# add the required classes (works directly on ldap entry !)
	set_attr($usr, 'objectClass', join(';',@{$config{unix_user_classes}}));

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

	# constant fields
	for my $attr (keys %unix_fields_const) {
		cond_set($usr, $attr, $unix_fields_const{$attr});
	}

	# fields for NT
	my %path_subst = (
		'SERVER'	=>	$config{home_server},
		'USER'		=>	$uid,
	);
	cond_set($usr, 'ntUserHomeDir',
			ifnull($uid, subst_path($config{ad_home_dir}, %path_subst)));
	cond_set($usr, 'ntUserProfile',
			ifnull($uid, subst_path($config{ad_profile_path}, %path_subst)));
	cond_set($usr, 'ntUserScriptPath',
			ifnull($uid, subst_path($config{ad_script_path}, %path_subst)));
	cond_set($usr, 'ntUserDomainId', $uid);
}


sub windows_user_groups
{
	my $name = $config{ad_primary_group};
	my $res = ldap_search($win, "(&(objectClass=group)(cn=$name))",
							[ 'PrimaryGroupToken' ] );
	my $group = $res->pop_entry;
	my $group_id = 0;
	$group_id = $group->get_value('PrimaryGroupToken') if defined $group;
	$group_id = 0 unless $group_id;		
	if ($res->code || !defined($group) || !$group_id) {
		message_box('error', 'close',
			_T('Error reading Windows group "%s" (%s): %s', $name, $group_id, $res->error));
	}

	my $filter = join('', map("(cn=$_)", @{$config{ad_user_groups}}));
	$res = ldap_search($win, "(&(objectClass=group)(|$filter))");
	if ($res->code) {
		message_box('error', 'close',
			_T('Error reading list of Windows groups: %s', $res->error));
	}

	my @sec_groups = $res->entries;
	return ($group_id, @sec_groups);
}


sub windows_user_dn ($)
{
	my $uo = shift;
	my $cn = get_attr($uo, 'cn');
	my $ad_dc_domain = path2dn($config{ad_domain},'dc');
	my $dn = "cn=$cn,".path2dn($config{ad_user_container}).",$ad_dc_domain";
	return $dn;
}


sub rework_windows_account ($)
{
	my $uo = shift;

	my $uid = get_attr($uo, 'uid');
	my $cn = get_attr($uo, 'cn');

	log_debug('rework windows user %s (%s) ...', $uid, $cn);

	my $wo = {
		changed => 0,
		a => {},
	};
	my $res = ldap_search($win, "(&(objectClass=user)(cn=$cn))", [ '*', 'unicodePwd' ]);
	$wo->{ldap} = $res->pop_entry;

	if (defined($wo->{ldap})) {
		for my $attr ($wo->{ldap}->attributes(nooptions => 1)) {
			my $type = 's';
			my $a = {
				parent => $wo,
				visual => 0,
				type => $type,
				attr => $attr,
			};
			get_ldap_attr($a);
			$wo->{a}->{$attr} = $a;
		}
		$wo->{dn} = $uo->{ldap}->dn;
	}
	else {
		log_info('creating windows user (%s) for uid (%s) ...', $cn, $uid);			
		my $obj_cat = join(',', path2dn($config{ad_user_category}),
								path2dn($config{ad_domain},'dc'));
		$wo->{ldap} = Net::LDAP::Entry->new();
		$wo->{ldap}->add(objectClass => $config{ad_user_classes});
		$wo->{changed} = 1;
		cond_set($wo, 'cn', $cn);
		cond_set($wo, 'instanceType', 4);
		cond_set($wo, 'objectCategory', $obj_cat);

		if (defined($config{ad_initial_pass})) {
			my $unipwd = "";
			map { $unipwd .= "$_\000" } split(//, "\"$config{ad_initial_pass}\"");
			cond_set($wo, 'unicodePwd', $unipwd);
			# FIXME! also need to change unix pwd
		}

		cond_set($wo, 'userAccountControl', 512);
		# FIXME! #ADS_UF_NORMAL_ACCOUNT);

		$wo->{dn} = windows_user_dn($uo);
	}

	my $ad_principal = $uid.'@'.$config{ad_domain};
	cond_set($wo, 'userPrincipalName', $ad_principal);	

	# copy fields from unix
	for my $wattr (keys %ad_fields_from_unix) {
		next unless $wattr;
		my $uattr = $ad_fields_from_unix{$wattr};
		my $ok = ($uattr && has_attr($uo, $uattr));
		next unless $ok;
		cond_set($wo, $wattr, get_attr($uo, $uattr));
	}

	# constant fields
	for (keys %ad_fields_const) {
		cond_set($wo, $_, $ad_fields_const{$_});
	}

	my ($primary_group_id, @secondary_groups) = windows_user_groups();
	# AD refuses to set PrimaryGroupID and by default adds to the Domain Users group.
	#cond_set($wo, 'PrimaryGroupID', $primary_group_id);

	# update on server
	my $a;
	for $a (values %{$wo->{a}}) {
		$a->{cur} = $a->{val};
		$wo->{changed} = 1 if $a->{cur} ne $a->{orig};
	}
	if ($wo->{changed}) {
		$wo->{dn} = windows_user_dn($uo) unless $wo->{dn};
		for $a (values %{$wo->{a}}) { set_ldap_attr($a); }
		$wo->{ldap}->dn($wo->{dn});
		$res = ldap_update($win, $wo->{ldap});
		if ($res->code) {
			message_box('error', 'close',
				_T('Error updating Windows-user "%s" (%s): %s',
				$cn, $wo->{ldap}->dn, $res->error));
		}
	}

	# add to required groups
	my $dn = $wo->{dn};
	for my $grp (@secondary_groups) {
		my $name = $grp->get_value('name');
		my %members;
		for ($grp->get_value('member')) { $members{$_} = 1; }
		unless (defined $members{$dn}) {
			$grp->add( member => $dn );
			my $res = ldap_update($win, $grp);
			if ($res->code) {
				message_box('error', 'close',
					_T('Error adding "%s" to Windows-group "%s": %s', $cn, $name, $res->error));
			}
		}
	}

}


sub rework_home_dir ($)
{
	my $usr = shift;
	my $home = get_attr($usr, 'homeDirectory');
	log_info('probably creating home directory "%s"', $home);
	return 0 if $home eq '';
	return 2 if -d $home;

	log_info('creating home directory "%s"', $home);
	$install{src} = $config{skel_dir};
	$install{dst} = $home;
	$install{uid} = get_attr($usr, 'uidNumber');
	$install{gid} = get_attr($usr, 'gidNumber');

	my $ret = File::Copy::Recursive::rcopy($install{src}, $install{dst});
	find(sub {
			# FIXME: is behaviour `lchown'-compatible ?
			chown $install{uid}, $install{gid}, $File::Find::name;
		}, $install{dst});
	return $ret > 0 ? 1 : -1;
}


# NOTE: structure of this routine is correct
#       user massage routines shouls work the same way
sub rework_unix_group ($)
{
	my $grp = shift;

	set_attr($grp, 'objectClass', join_list(@{$config{unix_group_classes}}));

	my $a = get_attr($grp, 'cn');
	set_attr($grp, 'cn', string2id($a));

	$a = get_attr($grp, 'gidNumber');
	$a = next_unix_gidn() unless $a;
	$a =~ tr/0123456789//cd;
	set_attr($grp, 'gidNumber', $a);

	my $dn = $config{unix_group_dn};
	for $a (values %{$grp->{a}}) {
		$dn =~ s/\[$a->{attr}\]/$a->{val}/g;
		last if $dn !~ /\[\w+\]/;
	}
	$grp->{dn} = $dn;
}


# ======== connections ========


sub ldap_search
{
	my ($srv, $filter, $attrs, $base, %params) = @_;
	$params{filter} = $filter;
	$params{base} = $base ? $base : $srv->{cfg}->{base};
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

	if ($cfg->{disabled}) {
		$ldap = Net::LDAP->new;
		$ldap->{cfg} = $cfg;
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
			s/^\s*//;
			s/\s*$//;
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
	return $ldap;
}


sub connect_all
{
	$srv = ldap_connect("srv");
	$win = ldap_connect("win");	
}


sub disconnect_all
{
	$srv->unbind unless $srv->{cfg}->{disabled};
	$win->unbind unless $win->{cfg}->{disabled};
}


# ======== user gui =========


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

	$usr->{dn} = unix_user_dn($usr) unless $usr->{dn};
	for my $a (values %{$usr->{a}}) { set_ldap_attr($a); }
	$usr->{ldap}->dn($usr->{dn});

	my $res = ldap_update($srv, $usr->{ldap});
	if ($res->code && $res->code != 82) {
		# Note: code 82 = `no values to update'
		message_box('error', 'close',
				_T('Error saving user "%s" (%s): %s', $uid, $usr->{ldap}->dn, $res->error));
		return;
	}
	log_info("saved unix user (%s)", $usr->{dn});
	for my $a (values %{$usr->{a}}) { set_ldap_attr_final($a); }

	rework_accounts($uid);
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
	my $model = $user_list->get_model;
	my $uo = $user_obj;

	my $node = $model->get_iter_first;
	while (defined $node) {
		return if is_new_user($node);
		$node = $model->iter_next($node);
	}

	$node = $model->append(undef);
	$model->set($node, 0, '-', 1, '-');
	my $path = $model->get_path($node);
	$user_list->set_cursor($path);
	$uo->{a}->{$user_gui_attrs[0][1][1]}->{entry}->grab_focus;
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
	my $uo = $user_obj;

	if (is_new_user($node)) {
		my $resp = message_box('question', 'yes-no', _T('Cancel new user ?', $uid));
		return if $resp ne 'yes';		
	} else {
		my $resp = message_box('question', 'yes-no', _T('Delete user "%s" ?', $uid));
		return if $resp ne 'yes';

		my $res = ldap_delete($srv, $uo->{ldap});
		if ($res->code) {
			message_box('error', 'close',
					_T('Error deleting Unix-user "%s": %s', $uid, $res->error));
			return;
		}
		unless ($win->{cfg}->{disabled}) {
			my $win_dn = windows_user_dn($uo);
			$res = ldap_delete($win, $win_dn);
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
		$user_list->set_cursor($path);
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

	my $res = ldap_search($srv, "(objectClass=person)", \@attrs);
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
	my $uo = $user_obj;

	$user_name->set_text('');

	for my $ua (values %{$user_obj->{a}}) {
		next unless $ua->{visual};
		$ua->{entry}->set_text('');
		$ua->{entry}->set_editable(0);
		$ua->{bulb}->set_from_pixbuf(create_pic('empty.png'));
	}

	$btn_usr_apply->set_sensitive(0);
	$btn_usr_revert->set_sensitive(0);
	$btn_usr_delete->set_sensitive(0);

	$user_attr_tabs->set_current_page(0);
	$user_attr_frame->set_sensitive(0);

	undef $uo->{ldap};
	undef $uo->{dn};
	$uo->{changed} = 0;

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
	my $a;

	if (is_new_user($node)) {
		$usr->{ldap} = Net::LDAP::Entry->new;
		for $a (values %{$usr->{a}}) { $a->{cur} = ''; set_ldap_attr($a); }
	} else {
		my $res = ldap_search($srv, "(&(objectClass=person)(uid=$uid))");
		if ($res->code || scalar($res->entries) == 0) {
			my $msg = _T('Cannot display user "%s"', $uid);
			$msg .= ": ".$res->error if $res->code;
			message_box('error', 'close', $msg);
			return;
		}
		$usr->{ldap} = $res->pop_entry;
	}

	for $a (values %{$usr->{a}}) {
		get_ldap_attr($a);
		next unless $a->{visual};
		$a->{entry}->set_text($a->{val});
		$a->{entry}->set_editable(1);
		my $pic =  $state2pic{$a->{state}};
		$pic = 'empty.png' unless defined $pic;
		$a->{bulb}->set_from_pixbuf(create_pic($pic));
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
	my $usr = $a1->{parent};
	return unless $usr;

	$a1->{val} = $a1->{usr} = nvl($a1->{entry}->get_text);
	return if $a1->{cur} eq $a1->{val};

	# calculate calculatable fields
	my $a;
	for $a (values %{$usr->{a}}) {
		$a->{prev_state} = $a->{state};
		$a->{prev} = $a->{cur};
		$a->{cur} = $a->{val};
	}
	my $chg = $usr->{changed};
	$a1->{state} = 'user';
	rework_unix_account_entry($usr);
	$usr->{changed} = $chg;

	# analyze results
	$chg = 0;
	for $a (values %{$usr->{a}}) {
		next unless $a->{visual};
		my $val = nvl($a->{val});
		$a->{cur} = $val;
		my $state;
		if ($val eq '') {
			$state = 'empty';
		} elsif ($val eq $a->{orig}) {
			$state = 'orig';
		} elsif ($val eq $a->{prev}) {
			$state = $a->{prev_state};
		} elsif ($val eq $a->{usr}) {
			$state = 'user';
		} else {
			$state = 'calc';
		}
		$a->{state} = $state;
		if ($val ne $a->{usr}) {
			my $entry = $a->{entry};
			my $pos = $entry->get_position;
			$entry->set_text($val);
			$entry->set_position($pos);
		}
		$chg = 1 if $val ne $a->{orig};
	}

	# refresh bulbs
	for $a (values %{$usr->{a}}) {
		next unless $a->{visual};
		next if $a->{state} eq $a->{prev_state};
		my $pic =  $state2pic{$a->{state}};
		$pic = 'empty.png' unless defined $pic;
		$a->{bulb}->set_from_pixbuf(create_pic($pic));			
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
	$btn_usr_apply->set_sensitive($chg);
	$btn_usr_revert->set_sensitive($chg);
	$btn_usr_refresh->set_sensitive(!$chg);
	$btn_usr_add->set_sensitive(!$chg);
	$btn_usr_delete->set_sensitive(!$chg);
	$user_list->set_sensitive(!$chg);
}


sub user_group_toggled ($$)
{
	my ($btn, $a) = @_;
	my $uid = $btn->get_label;
	my $active = $btn->get_active;
	set_button_image($btn, $active ? 'green.png' : 'empty.png');

	my @groups;
	for (split_list $a->{entry}->get_text) {
		next unless $_;
		push @groups, $_ if $_ ne $uid;	
	}
	push @groups, $uid if $active;
	$a->{cur} = join_list sort @groups;
	set_user_changed(1) if $a->{cur} ne $a->{orig};
	$a->{entry}->set_text($a->{cur});
}


sub create_user_groups_editor ($)
{
	my $ua = shift;
	my $popup_btn = $ua->{popup};

	my $res = ldap_search($srv, "(objectClass=posixGroup)", ['cn']);
	my @groups = $res->entries;
	return if $#groups < 0;

	my $wnd = Gtk2::Window->new("toplevel");
	$wnd->set_title('---');
	my $vbox = Gtk2::VBox->new(0, 0);
	$wnd->add($vbox);
	my $scroll = Gtk2::ScrolledWindow->new;
	$vbox->pack_start($scroll, 1, 1, 1);
	$scroll->set_policy("automatic", "automatic");
	my $list = new Gtk2::VBox(0, 0);
	$scroll->add_with_viewport($list);

	my %groups0;
	map { $groups0{$_} = 1 } split_list $ua->{entry}->get_text;	

	for my $gid (sort {$a cmp $b} map {$_->get_value('cn')} @groups) {
		my $btn = new Gtk2::ToggleButton($gid);
		my $active = defined $groups0{$gid};
		set_button_image($btn, $active ? 'green.png' : 'empty.png');
		$btn->set_active($active);
		$btn->signal_connect(toggled => sub { user_group_toggled($btn, $ua); });
		$list->pack_start($btn, 0, 0, 0);
	}

	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) } ],
	);

	$vbox->pack_end($buttons, 0, 0, 2);
	$wnd->set_default_size(200, 200);
	$wnd->set_transient_for($main_wnd);
	$wnd->set_position('center_on_parent');
	#$wnd->set_deletable(0); not available in GTK+ 2.8 on Windows
	$wnd->set_modal(1);
	$wnd->signal_connect(delete_event	=> sub { destroy_popup($wnd, $popup_btn) });
	$wnd->signal_connect(destroy		=> sub { destroy_popup($wnd, $popup_btn) });
	$popup_btn->set_sensitive(0);
	$wnd->show_all;
	set_window_icon($wnd, "popup.png");
}


sub create_group_chooser ($)
{
	my $ua = shift;
	my $popup_btn = $ua->{popup};

	my $res = ldap_search($srv, "(objectClass=posixGroup)", ['cn']);
	my @groups = $res->entries;
	return if $#groups < 0;
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

	for (@user_gui_attrs) {
		my ($tab_name, @tab_attrs) = @$_;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, $tab_name);
		$scroll->set_policy('automatic', 'automatic');
		$scroll->set_border_width(0);

		my $abox = Gtk2::Table->new($#tab_attrs + 1, 4);
		$scroll->add_with_viewport($abox);

		for my $r (0 .. $#tab_attrs) {
			my $gui_attr = $tab_attrs[$r];
			my ($type, $attr, $text) = @$gui_attr;
			my $label = Gtk2::Label->new($text);
			$label->set_justify('left');
			my $entry = Gtk2::Entry->new;
			my $bulb = Gtk2::Image->new;
			my $a = {
				parent => $usr,
				visual => 1,
				type => $type,
				attr => $attr,
				entry => $entry,
				bulb => $bulb,
			};
			$usr->{a}->{$attr} = $entry->{friend} = $a;
			$abox->attach($bulb, 0, 1, $r, $r+1, [], [], 1, 1);
			$abox->attach($label, 1, 2, $r, $r+1, [], [], 1, 1);
			my $right = 4;
			if ($type eq 'G') {
				my $popup_btn = create_button(undef, 'popup.png');
				$a->{popup} = $popup_btn;
				$popup_btn->signal_connect(clicked =>
								sub { create_user_groups_editor($a); });
				$popup_btn->set_relief('none');
				$abox->attach($popup_btn, 3, 4, $r, $r+1, [], [], 1, 1);
				$right = 3;
			} elsif ($type eq 'g') {
				my $popup_btn = create_button(undef, 'popup.png');
				$a->{popup} = $popup_btn;
				$popup_btn->signal_connect(clicked =>
								sub { create_group_chooser($a); });
				$popup_btn->set_relief('none');
				$abox->attach($popup_btn, 3, 4, $r, $r+1, [], [], 1, 1);
				$right = 3;
			}
			$abox->attach($entry, 2, $right, $r, $r+1, [ 'fill', 'expand' ], [], 1, 1);
			$entry->signal_connect(key_release_event => \&user_entry_attr_changed)
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

	my $a = $grp->{a}->{description};
	$a->{cur} = $gid if nvl($a->{cur}) eq '';

	for $a (values %{$grp->{a}}) { set_ldap_attr($a); }
	$grp->{ldap}->dn($grp->{dn}) if $grp->{dn};

	my $res = ldap_update($srv, $grp->{ldap});
	if ($res->code && $res->code != 82) {
		# Note: code 82 = `no values to update'
		message_box('error', 'close',
			_T('Error saving group "%s": %s', $gid, $res->error));
		return;
	}
	for $a (values %{$grp->{a}}) { set_ldap_attr_final($a); }

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

	$grp->{a}->{$group_gui_attrs[0][1][1]}->{entry}->grab_focus;
	set_group_changed(0);
	$btn_grp_add->set_sensitive(0);

	group_select();
}


sub group_delete
{
	my ($path, $column) = $group_list->get_cursor;
	return unless defined $path;
	my $model = $group_list->get_model;
	my $go = $group_obj;

	my $node = $model->get_iter($path);
	my $gid = $model->get($node, 0);

	if (is_new_group($node)) {
		my $resp = message_box('question', 'yes-no', _T('Cancel new group ?', $gid));
		return if $resp ne 'yes';		
	} else {
		my $resp = message_box('question', 'yes-no', _T('Delete group "%s" ?', $gid));
		return if $resp ne 'yes';

		my $res = ldap_delete($srv, $go->{ldap});
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

	my $res = ldap_search($srv, '(objectClass=posixGroup)', ['cn']);
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

	for my $a (values %{$grp->{a}}) {
		next unless $a->{visual};
		$a->{entry}->set_text('');
		$a->{entry}->set_editable(0);
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
	my $a;

	if (is_new_group($node)) {
		$grp->{ldap} = Net::LDAP::Entry->new;
		for $a (values %{$grp->{a}}) { $a->{cur} = ''; set_ldap_attr($a); }
	} else {
		my $res = ldap_search($srv, "(&(objectClass=posixGroup)(cn=$gid))");
		if ($res->code || scalar($res->entries) == 0) {
			my $msg = _T('Cannot display group "%s"', $gid);
			$msg .= ": ".$res->error if $res->code;
			message_box('error', 'close', $msg);
			return;
		}
		$grp->{ldap} = $res->pop_entry;
		$grp->{dn} = $grp->{ldap}->dn;
	}

	for $a (values %{$grp->{a}}) {
		get_ldap_attr($a);
		next unless $a->{visual};
		$a->{entry}->set_text($a->{val});
		$a->{entry}->set_editable(1);
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
	my $grp = $a1->{parent};
	return unless $grp;

	$a1->{val} = $a1->{usr} = nvl($a1->{entry}->get_text);
	return if $a1->{cur} eq $a1->{val};
	$a1->{cur} = $a1->{val};

	rework_unix_group($grp);

	my $chg = 0;
	for my $a (values %{$grp->{a}}) {
		$chg = 1 if $a->{val} ne $a->{orig};
		next if $a->{val} eq $a->{cur};
		$a->{cur} = $a->{val};
		next unless $a->{visual};
		my $entry = $a->{entry};
		my $pos = $entry->get_position;
		$entry->set_text($a->{val});
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
	$btn_grp_apply->set_sensitive($chg);
	$btn_grp_revert->set_sensitive($chg);
	$btn_grp_refresh->set_sensitive(!$chg);
	$btn_grp_add->set_sensitive(!$chg);
	$btn_grp_delete->set_sensitive(!$chg);
	$group_list->set_sensitive(!$chg);
}


sub group_user_toggled ($$)
{
	my ($btn, $ga) = @_;
	my $uid = $btn->get_label;
	my $active = $btn->get_active;
	set_button_image($btn, $active ? 'green.png' : 'empty.png');

	my @users;
	for (split_list $ga->{entry}->get_text) {
		next unless $_;
		push @users, $_ if $_ ne $uid;	
	}
	push @users, $uid if $active;
	$ga->{val} = $ga->{cur} = join_list sort @users;
	set_group_changed(1) if $ga->{val} ne $ga->{orig};
	$ga->{entry}->set_text($ga->{val});
}


sub create_group_users_editor ($)
{
	my $ga = shift;
	my $popup_btn = $ga->{popup};

	my $res = ldap_search($srv, "(objectClass=person)", ['uid']);
	my @users = $res->entries;
	return if $#users < 0;

	my $wnd = Gtk2::Window->new("toplevel");
	$wnd->set_title('---');
	my $vbox = Gtk2::VBox->new(0, 0);
	$wnd->add($vbox);
	my $scroll = Gtk2::ScrolledWindow->new;
	$vbox->pack_start($scroll, 1, 1, 1);
	$scroll->set_policy("automatic", "automatic");
	my $list = new Gtk2::VBox(0, 0);
	$scroll->add_with_viewport($list);

	my %users0;
	map { $users0{$_} = 1 } split_list $ga->{entry}->get_text;	

	for my $uid (sort {$a cmp $b} map {$_->get_value('uid')} @users) {
		my $btn = new Gtk2::ToggleButton($uid);
		my $active = defined $users0{$uid};
		set_button_image($btn, $active ? 'green.png' : 'empty.png');
		$btn->set_active($active);
		$btn->signal_connect(toggled => sub { group_user_toggled($btn, $ga); });
		$list->pack_start($btn, 0, 0, 0);
	}

	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) } ],
	);

	$vbox->pack_end($buttons, 0, 0, 2);
	$wnd->set_default_size(200, 200);
	$wnd->set_transient_for($main_wnd);
	$wnd->set_position('center_on_parent');
	# note: set_deletable is absent from Gtk+ 2.8 on Windows
	#$wnd->set_deletable(0);
	$wnd->set_modal(1);
	$wnd->signal_connect(delete_event	=> sub { destroy_popup($wnd, $popup_btn) });
	$wnd->signal_connect(destroy		=> sub { destroy_popup($wnd, $popup_btn) });
	$popup_btn->set_sensitive(0);
	$wnd->show_all;
	set_window_icon($wnd, "popup.png");
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

	for (@group_gui_attrs) {
		my ($tab_name, @tab_attrs) = @$_;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, $tab_name);
		$scroll->set_policy('automatic', 'automatic');
		$scroll->set_border_width(0);

		my $abox = Gtk2::Table->new($#tab_attrs + 1, 3);
		$scroll->add_with_viewport($abox);

		for my $r (0 .. $#tab_attrs) {
			my $gui_attr = $tab_attrs[$r];
			my ($type, $attr, $text) = @$gui_attr;
			my $label = Gtk2::Label->new($text);
			$label->set_justify('left');
			my $entry = Gtk2::Entry->new;

			my $a = {
				parent => $grp,
				visual => 1,
				type => $type,
				attr => $attr,
				entry => $entry,
			};
			$grp->{a}->{$attr} = $entry->{friend} = $a;

			$abox->attach($label, 0, 1, $r, $r+1, [], [], 1, 1);
			my $right = 3;
			if ($type eq 'U') {
				my $popup_btn = create_button(undef, 'popup.png');
				$a->{popup} = $popup_btn;
				$popup_btn->signal_connect(clicked =>
								sub { create_group_users_editor($a); });
				$popup_btn->set_relief('none');
				$abox->attach($popup_btn, 2, 3, $r, $r+1, [], [], 1, 1);
				$right = 2;
			}
			$abox->attach($entry, 1, $right, $r, $r+1, [ 'fill', 'expand' ], [], 1, 1);
			$entry->signal_connect(key_release_event => \&group_entry_attr_changed)
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
	log_error('usage: $pname [-d]') if !$cmd_ok || $opts{h};

	configure(@{$config{config_files}});
	dump_config() if $opts{D};
	$config{debug} = 1 if $opts{d};

	connect_all();

	Gtk2->init;
	my $gtkrc;
	Gtk2::Rc->parse($gtkrc) if defined $gtkrc;
	$main_wnd = Gtk2::Window->new("toplevel");

	my $tabs = Gtk2::Notebook->new;
	$tabs->set_tab_pos("top");

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
	$main_wnd->signal_connect(map	=> sub { users_refresh(); groups_refresh(); });

	$main_wnd->set_default_size(900, 600);
	$main_wnd->show_all;
	set_window_icon($main_wnd, "tree.png");

	Gtk2->main;

	disconnect_all();
}

gui_main();
