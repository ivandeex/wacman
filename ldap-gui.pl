#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use strict;
use warnings;
#no warnings 'utf8';
use utf8;
#use open ':utf8';
use Carp;
use Getopt::Std;
use Gtk2;
use POSIX;
use Encode;
use Net::LDAP;
use Net::LDAP::Entry;
use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;


my ($srv, $win, $pname);

my $changed;
my ($btn_apply, $btn_revert, $btn_fill);
my ($btn_add, $btn_delete, $btn_refresh);
my ($user_list, $user_name, $main_win);
my ($user_attrs, @user_attr_entries, $user_attr_tabs);
my ($orig_acc, $edit_acc);


# ======== config =========


use constant NO_EXPIRE => '9223372036854775807';
use constant SAM_USER_OBJECT => hex('0x30000000');
use constant ADS_UF_NORMAL_ACCOUNT => hex(0x00000200);


my %servers = (
	win => {
		uri		=>	'ldaps://xxx.winsrv.vpn',
		user	=>	'cn=syncadmin,cn=builtin,dc=gclimate,dc=local',
		passfile=>	'/etc/ldap-gui.secret',
		base	=>	'dc=gclimate,dc=local',
		debug	=>	0,
		convert	=>	0,
	},
	srv => {
		uri		=>	'ldaps://xxx.el4.vihens.ru',
		user	=>	'cn=dirman',
		passfile=>	'/etc/ldap-gui.secret',
		base	=>	'dc=vihens,dc=ru',
		debug	=>	0,
		convert	=>	1,
	}
);


my %config = (
	config_files		=>	[
			'/etc/ldap-gui.cfg',
			'~/.ldap-gui.cfg',
			'./ldap-gui.cfg'
		],
	skel_dir			=>	'/etc/skel',
	xinstall_command	=>	'/usr/bin/sudo -S /usr/local/sbin/xinstall',
	user_class			=>	'person',
	unix_user_dn		=>	'uid=[uid],ou=People,dc=vihens,dc=ru',

	ad_initial_pass		=>	'123qweASD',
	unix_user_classes	=>	[
			qw(top person organizationalPerson inetOrgPerson posixAccount shadowAccount ntUser)
		],	
	ad_user_classes		=>	[ qw(top user person organizationalPerson) ],	
	ad_user_category	=>	'Person.Schema.Configuration',
	ad_primary_group	=>	'Пользователи домена',
	ad_user_groups		=>	[ 'Пользователи удаленного рабочего стола' ],
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
		[ 's', 'givenName', 'Имя' ],
		[ 's', 'sn', 'Фамилия' ],
		[ 's', 'cn', 'Полное имя' ],
		[ 'd', 'uid', 'Идентификатор' ],
		[ 's', 'mail', 'почта' ],
		[ 's', 'uidNumber', '#пользователя' ],
		[ 'g', 'gidNumber', '#группы' ],
		[ 'G', '', 'прочие группы' ],
		[ 's', 'homeDirectory', 'домашний каталог' ],
		[ 's', 'loginShell', 'Shell' ],
	],
	[ 'Windows',
		[ 's', 'ntUserHomeDir', 'Домашний каталог' ],
		[ 's', 'ntUserHomeDirDrive', 'Диск' ],
		[ 's', 'ntUserProfile', 'Профиль' ],
		[ 's', 'ntUserScriptPath', 'Сценарий входа' ]
	],
	[ 'Дополнительно',
		[ 's', 'telephoneNumber', 'Телефон' ],
		[ 's', 'facsimileTelephoneNumber', 'Факс' ],
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
				die "incorrect section \"$mode\" in $file: $_\n"
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
				die "incorrect line in $file: $_\n";
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
		$val = ($val =~ /^ARRAY\(\S+\)$/) ? '[ '.join(', ',map("\"$_\"",@$val)).' ]' : "\"$val\"";
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


sub ldap_convert_attr
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

sub ldap_attr2disp { return ldap_convert_attr($_[0], $_[1], 0); }

sub ldap_disp2attr { return ldap_convert_attr($_[0], $_[1], 1); }


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


my $log;

sub init_log ($)
{
	my $level = shift;
	$level = 'warn' unless $level;
	$level = lc($level);
	my %levels = (
		0 => $FATAL,	fatal => $FATAL,
		1 => $ERROR,	error => $ERROR,
		2 => $WARN,		'warn'=> $WARN,
		3 => $INFO,		info  => $INFO,
		4 => $DEBUG,	debug => $DEBUG,
		5 => $TRACE,	trace => $TRACE,
	);
	croak "unknown log level $level\n" unless defined($levels{$level});
	$level = $levels{$level};
	$log = Log::Log4perl->get_logger("refresh");
	my $layout = Log::Log4perl::Layout::PatternLayout->new('%d %c %p: %m%n');
	my $stdout_appender =  Log::Log4perl::Appender->new(
				"Log::Log4perl::Appender::Screen",
				name      => "screenlog",
				stderr    => 0);
	$stdout_appender->layout($layout);
	$log->add_appender($stdout_appender);
	$log->level($level);
}


# ======== gui utils ========


use FindBin qw[$Bin];
use Cwd 'abs_path';

my $pic_home = abs_path("$Bin/images");


my %pic_cache;

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
	my $button = Gtk2::Button->new_with_label($text);
	$button->set_image(Gtk2::Image->new_from_pixbuf(create_pic($pic))) if $pic;		
	$button->signal_connect("clicked" => $action) if $action;
	$owner_box->pack_start($button, 0, 0, 1) if $owner_box;
	return $button;
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
	my $dia = Gtk2::MessageDialog->new ($main_win, 'destroy-with-parent',
										$type, $buttons, $message);
	my $ret = $dia->run;
	$dia->destroy;
	return $ret;
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
	tr/абвгдежзийклмнопрстуфхцчшщъыьэюя/abvgdewzijklmnoprstufhc4wwxyxeuq/;		
	tr/АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ/ABVGDEWZIJKLMNOPRSTUFHC4WWXYXEUQ/;
	$_ = lc;
	tr/0-9a-z/_/cs;
	$_;
}


# ======== massage ========


my $next_uidn;

sub next_unix_uidn
{
	if (defined($next_uidn) && $next_uidn > 0) {
		return $next_uidn;
	}
	$next_uidn = 0;
	my $res = ldap_search( $srv,
					base => $srv->{CFG}->{base},
					filter => "(objectClass=posixAccount)",
					attrs => [ 'uidNumber' ] );
	for ($res->entries) {
		my $uidn = $_->get_value('uidNumber');
		$next_uidn = $uidn if $uidn > $next_uidn;
	}
	$next_uidn = $next_uidn > 0 ? $next_uidn + 1 : 1000;
	$log->debug("next=$next_uidn");
	return $next_uidn;
}


sub unix_dn ($)
{
	my $ua = shift;
	my $dn = $config{unix_user_dn};
	my $uid = $ua->get_value('uid');
	my $cn = $ua->get_value('cn');
	$dn =~ s/\[uid\]/$uid/g;
	$dn =~ s/\[cn\]/$uid/g;
	return $dn;
}


sub massage_accounts
{
	my @ids = @_;
	if ($#ids < 0) {
		my $user_class = $config{user_class};
		my $res = ldap_search( $srv,
						base => $srv->{CFG}->{base},
						filter => "(objectClass=$user_class)",
						attrs => [ 'uid' ] );
		# get all users
		@ids = map { $_->get_value('uid') } $res->entries;
	}
	for my $id (@ids) {
		$log->debug("massage id $id ...");
		my $ua = massage_unix_account($id);
		if (defined $ua) {
			massage_home_dir($ua);
			# at this point we need to tell FDS to synchronize
			massage_windows_account($ua);
		}
	}
}


sub massage_unix_account
{
	my $id = shift;
	my $user_class = $config{user_class};
	my $res = ldap_search(	$srv,
					base => $srv->{CFG}->{base},
					filter => "(&(objectClass=$user_class)(uid=$id))" );
	if ($res->code) {
		$res = ldap_search( $srv,
					base => $srv->{CFG}->{base},
					filter => "(&(objectClass=person)(cn=$id))" )
	}
	if ($res->code) {
		message_box('error', 'close', "Не найден пользователь \"$id\": ".$res->error);
		return;
	}
	my $ua = $res->pop_entry;
	if (defined $ua) {
		if (massage_unix_account_entry($ua)) {
			$res = ldap_update($srv, $ua); 
			my $uid = $ua->get_value('uid');
			$log->info("changed: uid=($uid), ret=(".$res->error.")");
		}
	} else {
		message_box('error', 'close', "Не найден пользователь: \"$id\"");
	}
	return $ua;
}


sub massage_unix_account_entry
{
	my $ua = shift;

	# read all scalar attributes
	my $uchange = 0;
	my $uid = nvl($ua->get_value('uid'));
	my $cn = nvl($ua->get_value('cn'));
	my $gn = nvl($ua->get_value('givenName'));
	my $sn = nvl($ua->get_value('sn'));

	# names
	unless (ldap_has_attr($ua, 'cn')) {
		my $bl = $sn && $gn ? ' ' : '';
		$cn = "$gn$bl$sn";
		$uchange++ if ldap_cond_set($ua, 'cn', $cn);
	}

	# user id
	unless (ldap_has_attr($ua, 'uid')) {
		$uid = string2id($sn eq '' ? $gn : substr($gn, 0, 1) . $sn);
		$uchange++ if ldap_cond_set($ua, 'uid', $uid);
	}

	# dn
	if (nvl($ua->dn) eq '') {
		$ua->dn(unix_dn($ua));
	}

	# add the required classes
	my (%classes);
	for ($ua->get_value('objectClass')) { $classes{$_} = $classes{lc} = 1; }
	for my $class (@{$config{unix_user_classes}}) {
		my $lclass = lc($class);
		unless (defined($classes{$class}) || defined($classes{$lclass})) {
			$ua->add(objectClass => $class);
			$log->debug("$uid($cn): add class $class");
			$uchange++;
		}
	}

	# assign next available UID number
	unless (ldap_has_attr($ua, 'uidNumber')) {
		$uchange++ if ldap_cond_set($ua, 'uidNumber', next_unix_uidn());
	}

	# mail
	$uchange++ if ldap_cond_set($ua, 'mail', ifnull($uid, $uid.'@'.$config{unix_domain}));

	# home directory
	$uchange++ if ldap_cond_set($ua, 'homeDirectory', ifnull($uid, "/home/$uid"));

	# constant fields
	for my $attr (keys %unix_fields_const) {
		$uchange++ if ldap_cond_set($ua, $attr, $unix_fields_const{$attr});
	}

	# fields for NT
	my %path_subst = (
		'SERVER'	=>	$config{home_server},
		'USER'		=>	$uid,
	);
	$uchange++ if
		ldap_cond_set($ua, 'ntUserHomeDir',
					ifnull($uid,subst_path($config{ad_home_dir}, %path_subst)));
	$uchange++ if
		ldap_cond_set($ua, 'ntUserProfile',
					ifnull($uid,subst_path($config{ad_profile_path}, %path_subst)));
	$uchange++ if
		ldap_cond_set($ua, 'ntUserScriptPath',
					ifnull($uid,subst_path($config{ad_script_path}, %path_subst)));
	$uchange++ if
		ldap_cond_set($ua, 'ntUserDomainId', $uid);

	return $uchange;
}


sub windows_user_groups
{
	my $name = $config{ad_primary_group};
	my $filter = "(&(objectClass=group)(cn=$name))";
	my $res = ldap_search( $win, base => $win->{CFG}->{base},
							filter => $filter, attrs => [ 'PrimaryGroupToken' ] );
	my $group = $res->pop_entry;
	my $group_id = 0;
	$group_id = $group->get_value('PrimaryGroupToken') if defined $group;
	$group_id = 0 unless $group_id;		
	if ($res->code || !defined($group) || !$group_id) {
		message_box('error', 'close',
				"Ошибка чтения Windows-группы \"$name\" ($group_id): ".$res->error);
	}

	$filter = join('', map("(cn=$_)", @{$config{ad_user_groups}}));
	$filter = "(&(objectClass=group)(|$filter))";
	$res = ldap_search( $win, base => $win->{CFG}->{base}, filter => $filter );
	if ($res->code) {
		message_box('error', 'close',
				"Ошибка чтения списка Windows-групп: ".$res->error);
	}
	my @sec_groups = $res->entries;
	return ($group_id, @sec_groups);
}


sub windows_dn ($)
{
	my $ua = shift;
	my $cn = $ua->get_value('cn');
	my $ad_dc_domain = path2dn($config{ad_domain},'dc');
	my $dn = "cn=$cn,".path2dn($config{ad_user_container}).",$ad_dc_domain";
	return $dn;
}


sub massage_windows_account ($$)
{
	my ($ua, $new_pwd) = @_;
	my $uid = $ua->get_value('uid');
	my $cn = $ua->get_value('cn');

	$log->debug("massage windows $uid ($cn) ...");
	my $filter = "(&(objectClass=user)(cn=$cn))";
	my $wchange = 0;
	my $uchange = 0;
	my $base = $win->{CFG}->{base};
	my $attrs = [ '*', 'unicodePwd' ];

	my $res = ldap_search( $win, base => $base, filter => $filter, attrs => $attrs );
	my $wa = $res->pop_entry;

	# still need full resynchronization here !
	if ($res->code || !defined($wa))
	{
		$log->info("creating windows user ($cn) for uid ($uid) ...");			
		my $ad_dc_domain = path2dn($config{ad_domain},'dc');
		my $dn = "cn=$cn,".path2dn($config{ad_user_container}).",$ad_dc_domain";
		$wa = Net::LDAP::Entry->new();
		$wa->dn($dn);
		$wa->add(objectClass => $config{ad_user_classes});
		$log->debug("created windows user: $dn");
		$log->debug("$cn: object classes: ".join(',',@{$config{ad_user_classes}}).")");
		$wchange++;
		ldap_cond_set($wa, 'cn', $cn);
		ldap_cond_set($wa, 'instanceType', 4);
		my $obj_category = path2dn($config{ad_user_category}).",$ad_dc_domain";
		ldap_cond_set($wa, 'objectCategory', $obj_category);

		if (defined($config{ad_initial_pass})) {
			my $unipwd = "";
			map { $unipwd .= "$_\000" } split(//, "\"$config{ad_initial_pass}\"");
			ldap_cond_set($wa, 'unicodePwd', $unipwd);
			# FIXME! also need to change unix pwd
		}

		ldap_cond_set($wa, 'userAccountControl', 512);
		# FIXME! #ADS_UF_NORMAL_ACCOUNT);
	}

	my $ad_principal = $uid.'@'.$config{ad_domain};
	$wchange++ if ldap_cond_set($wa, 'userPrincipalName', $ad_principal);	

	# copy fields from unix
	my $wattr;
	for $wattr (sort keys %ad_fields_from_unix) {
		next unless $wattr;
		my $uattr = $ad_fields_from_unix{$wattr};
		my $ok = ($uattr && ldap_has_attr($ua, $uattr));
		next unless $ok;
		$wchange++ if ldap_cond_set($wa, $wattr, $ua->get_value($uattr));
	}

	# constant fields
	for $wattr (sort keys %ad_fields_const) {
		$wchange++ if ldap_cond_set($wa, $wattr, $ad_fields_const{$wattr});
	}

	# primary group
	my ($primary_group_id, @secondary_groups) = windows_user_groups();
	# AD refuses to set PrimaryGroupID and by default adds to the Domain Users group.
	#$wchange++ if ldap_cond_set($wa, 'PrimaryGroupID', $primary_group_id);

	# update on server
	if ($wchange) {
		$res = ldap_update($win, $wa);
		if ($res->code) {
			message_box('error', 'close',
				"Ошибка обновления Windows-пользователя \"$cn\": ".$res->error);
		}
		if ($uchange) {
			$res = ldap_update($srv, $ua);
			if ($res->code) {
				message_box('error', 'close',
					"Ошибка пере-обновления Unix-пользователя: ".$res->error);
			}
		}
	}

	#$res = $win->modify($wa->dn, replace => { "unicodePwd" => $unipwd });

	# add to required groups
	for my $grp (@secondary_groups) {
		my $name = $grp->get_value('name');
		my %members;
		for ($grp->get_value('member')) { $members{$_} = 1; }
		unless (defined $members{$wa->dn}) {
			$grp->add( member => $wa->dn );
			my $res = $grp->update($win);
			if ($res->code) {
				my $msg = "Ошибка добавления \"".$cn
						."\" в Windows-группу \"".$name."\": ".$res->error;
				message_box('error', 'close', $msg);
			}
		}
	}

}


sub massage_home_dir ($)
{
	my ($ua, $gotta_ask) = @_;
	my $home = $ua->get_value('homeDirectory');
	$log->debug("massage home $home ...");
	return 0 if -d $home;
	return 1 if $gotta_ask;
	$log->info("creating home: $home");
	my $skel = $config{skel_dir};
	my $xinstall = $config{xinstall_command};
	my $uid = $ua->get_value('uidNumber');
	my $gid = $ua->get_value('gidNumber');
	my $stdall = `$xinstall "$uid" "$gid" "$skel" "$home" 2>&1`;
	$log->debug("xinstall: [$stdall]");
	return 1;
}


# ======== connections ========


sub ldap_search
{
	my $srv = shift;
	my $res = $srv->search(@_);
	return $res;
}


sub ldap_update ($$)
{
	my ($srv, $ent) = @_;
	my $res = $ent->update($srv);
	undef $next_uidn;
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
	my ($uri, $user, $pass, $pfile) =
		($cfg->{uri}, $cfg->{user}, $cfg->{pass}, $cfg->{passfile});
	if (!$pass && $pfile) {
		open (PFILE, $pfile) or die "cannot open passfile $pfile\n";
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
	$log->logdie("invalid credentials for $ref") unless $uri && $user && $pass; 
	$ldap = Net::LDAP->new($uri, debug => $cfg->{debug})
		or die "cannot connect to $uri: ".$@."\n";
	$mesg = $ldap->bind($user, password => $pass);
	$log->logdie("cannot bind as $ref: ".$mesg->error) if $mesg->code;
	$ldap->{CFG} = $cfg;
	return $ldap;
}


sub connect_all
{
	$srv = ldap_connect("srv");
	$win = ldap_connect("win");	
}


sub disconnect_all
{
	$srv->unbind;
	$win->unbind;	
}


sub ldap_has_attr ($$)
{
	my ($record, $attr) = @_;
	my $gui_mode = defined($record->{user_attr}) ? 1 : 0;
	if ($gui_mode) {
		if (defined($record->{user_attr}->{$attr})) {
			my $state = $record->{user_attr}->{$attr}->{state};
			return 1 if $state eq 'user';
			return 0 if $state eq 'empty';
			return 1 if $state eq 'orig';
			return 0 if $state eq 'calc';
		}
		return 0;
	}
	if ($record->exists($attr)) {
		my $oldval = $record->get_value($attr); 
		if ($oldval && ($oldval !~ /^\s*$/)) {
			return 1;
		}
	}
	return 0;
}


sub ldap_cond_set ($$$)
{
	my ($record, $attr, $value) = @_;
	if (ldap_has_attr($record, $attr)) {
		return 0;
	}
	my $short_dn = '???';
	if (defined($record->dn)) {
		@_ = split(/,/, $record->dn);
		$short_dn = $_[0];
	}
	my $ret;
	if ($record->exists($attr)) {
		my $oldval = $record->get_value($attr);
		$record->replace($attr => $value);
		if (nvl($oldval) ne nvl($value)) {
			$log->debug("($short_dn): [$attr] := ($value)");
		}
		$ret = 1;
	} else {
		$record->add($attr => $value);
		$log->debug("($short_dn): [$attr] += ($value)");
		$ret = 2;
	}
	return $ret;
}


# ======== gui =========


sub is_new ($)
{
	my $node = shift;
	my $model = $user_list->get_model;
	return 0 unless defined $node;
	my $uid = $model->get($node, 0);
	my $cn = $model->get($node, 1);
	my $is_new = $uid eq '-' && $cn eq '-';
	return $is_new ? 1 : 0;
}


sub set_entry_attr ($$$)
{
	my ($ua, $e, $val) = @_;
	my $attr = $e->{attr};
	if ($attr) {
		croak "wow" unless defined $ua;
		if ($ua->exists($attr)) {
			$ua->replace($attr, $val);
		} else {
			$ua->add($attr => $val);
		}
	}
}


sub get_entry_attr ($$)
{
	my ($ua, $e) = @_;
	my $attr = $e->{attr};
	if ($attr) {
		return nvl($ua->get_value($attr));
	} else {
		return '';
	}
}


sub user_save
{
	my ($path, $column) = $user_list->get_cursor;
	return unless defined $path;
	return unless $changed;

	my $model = $user_list->get_model;
	my $node = $model->get_iter($path);
	my $uid = $user_attrs->{uid}->{cur_val};
	my $cn = $user_attrs->{cn}->{cur_val};
	$model->set($node, 0, $uid, 1, $cn);

	my $ua = $edit_acc;
	for my $e (@user_attr_entries) {
		set_entry_attr($ua, $e, $e->{cur_val});
	}
	my $old_dn = $ua->dn(unix_dn($ua));

	my $res = ldap_update($srv, $ua);
	if ($res->code) {
		message_box('error', 'close',
				"Ошибка сохранения пользователя \"$uid\": ".$res->error);
		return;
	}

	massage_accounts($uid);
	user_select();
	set_user_changed(0);
	$btn_add->set_sensitive(1);
}


sub user_revert
{
	my $resp = message_box('question', 'yes-no', "Действительно откатить модификации ?");
	return if $resp ne 'yes';
	set_user_changed(0);
	$btn_add->set_sensitive(1);
	user_select();
}


sub user_fill
{
}


sub user_add
{
	user_unselect();
	my $model = $user_list->get_model;

	my $node = $model->get_iter_first;
	while (defined $node) {
		return if is_new($node);
		$node = $model->iter_next($node);
	}

	$node = $model->append(undef);
	$model->set($node, 0, '-', 1, '-');
	my $path = $model->get_path($node);
	$user_list->set_cursor($path);
	my $first = $user_gui_attrs[0][1][1];
	$user_attrs->{$first}->{entry}->grab_focus;
	set_user_changed(0);
	$btn_add->set_sensitive(0);
	user_select($path, 0);
}


sub user_delete
{
	my ($path, $column) = $user_list->get_cursor;
	my $model = $user_list->get_model;
	return unless defined $path;

	my $node = $model->get_iter($path);
	my $uid = $model->get($node, 0);
	my $resp = message_box('question', 'yes-no', "Удалить пользователя \"$uid\"  ?");
	return if $resp ne 'yes';

	my $ua = $edit_acc;
	my $res = ldap_delete($srv, $ua);
	if ($res->code) {
		message_box('error', 'close',
			"Ошибка удаления Unix-пользователя \"$uid\": ".$res->error);
		return;
	}
	$res = ldap_delete($win, windows_dn($ua));
	if ($res->code) {
		message_box('error', 'close',
			"Ошибка удаления Windows-пользователя \"$uid\": ".$res->error);
	}

	$model->remove($node);
	set_user_changed(0);
	$btn_add->set_sensitive(1);

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
	massage_accounts();

	my @attrs = ('uid', 'cn');
	my $model = $user_list->get_model;
	$model->clear;

	my $user_class = $config{user_class};
	my $res = ldap_search( $srv,
					base => $srv->{CFG}->{base},
					filter => "(objectClass=$user_class)",
					attrs => \@attrs );
	my @users = $res->entries;
	@users = sort { $a->get_value('uid') cmp $b->get_value('uid') } @users;

	for my $entry (@users) {
		my $node = $model->append(undef);
		for my $i (0 .. $#attrs) {
			$model->set($node, $i, $entry->get_value($attrs[$i]));
		}
	}

	$btn_add->set_sensitive(1) if defined $btn_add;
}


sub user_change
{
	my ($path, $column) = $user_list->get_cursor;
	my $model = $user_list->get_model;
	if (defined $path) {
		my $node = $model->get_iter($path);
		$model->remove($node) if is_new($node);
		$btn_add->set_sensitive(1);
	}
}


sub user_unselect
{
	# exit if interface is not built complete
	return unless defined $user_name;

	$user_name->set_text('');

	@user_attr_entries = values %$user_attrs;
	for my $e (@user_attr_entries) {
		$e->{entry}->set_text('');
		$e->{entry}->set_editable(0);
		$e->{bulb}->set_from_pixbuf(create_pic('empty.png'));
	}

	$btn_apply->set_sensitive(0);
	$btn_revert->set_sensitive(0);
	$btn_fill->set_sensitive(0);
	$btn_delete->set_sensitive(0);

	$user_attr_tabs->set_current_page(0);

	undef $orig_acc;
	undef $edit_acc;

	$changed = 0;

	return 0;
}


sub user_select
{
	my ($path, $column) = $user_list->get_cursor;
	my $model = $user_list->get_model;
	my $node = $model->get_iter($path);
	my $uid = $model->get($node, 0);
	my $cn = $model->get($node, 1);
	return unless defined $uid;

	$user_name->set_text("$uid ($cn)");
	$btn_fill->set_sensitive(1);

	my ($ua, $e);
	if (is_new($node)) {
		$ua = Net::LDAP::Entry->new;
		for $e (@user_attr_entries) {
			set_entry_attr($ua, $e, '');
		}
	} else {
		my $user_class = $config{user_class};
		my $filter = "(&(objectClass=$user_class)(uid=$uid))";
		my $res = ldap_search(	$srv,
						base => $srv->{CFG}->{base}, filter => $filter );
		if ($res->code || scalar($res->entries) == 0) {
			my $msg = "Не могу вывести пользователя \"$uid\"";
			$msg .= ": ".$res->error if $res->code;
			message_box('error', 'close', $msg);
			return;
		}
		$ua = $res->pop_entry;
	}

	$orig_acc = $ua;
	undef $edit_acc;
	$edit_acc = $ua->clone;

	for $e (@user_attr_entries) {
		my $value = nvl($ua->get_value($e->{attr}));
		$e->{entry}->set_text($value);
		$e->{entry}->set_editable(1);
		$e->{new_val} = $e->{cur_val} = $e->{old_val} = $value;
		$e->{state} = $value eq '' ? 'empty' : 'orig'; 
		my $pic =  $state2pic{$e->{state}};
		$pic = 'empty.png' unless defined $pic;
		$e->{bulb}->set_from_pixbuf(create_pic($pic));
	}

	$btn_fill->set_sensitive(0);
	$btn_delete->set_sensitive(1);
	$user_attr_tabs->set_current_page(0);
}


sub user_entry_attr_changed
{
	my ($entry0, $event0) = @_;
	my $e0 = $entry0->{user_attr};
	return unless $e0;
	return unless $edit_acc;
	my $e;

	$e0->{new_val} = nvl($e0->{entry}->get_text());
	return if nvl($e0->{cur_val}) eq nvl($e0->{new_val});

	# read values
	for $e (@user_attr_entries) {
		$e->{old_state} = $e->{state};
		set_entry_attr($edit_acc, $e, $e->{new_val});
	}

	# calculate calculatable fields
	$e0->{state} = 'user';
	$edit_acc->{user_attr} = $user_attrs;
	massage_unix_account_entry($edit_acc);

	# analyze results
	my $chg = 0;
	for $e (@user_attr_entries) {
		my $val = get_entry_attr($edit_acc, $e);
		my $state = $e->{state};
		if ($val eq '') {
			$state = 'empty';
		} elsif ($val eq $e->{old_val}) {
			$state = 'orig';
		} elsif ($val eq $e->{cur_val}) {
			$state = $e->{old_state};
		} elsif ($val eq $e->{new_val}) {
			$state = 'user';
		} else {
			$state = 'calc';
		}
		$e->{cur_val} = $val;
		if ($val ne $e->{new_val}) {
			$e->{entry}->set_text($val);
		}
		$e->{state} = $state;
		$chg = 1 if $val ne $e->{old_val};
	}

	# refresh bulbs
	for $e (@user_attr_entries) {
		if ($e->{state} ne $e->{old_state}) {
			my $pic =  $state2pic{$e->{state}};
			$pic = 'empty.png' unless defined $pic;
			$e->{bulb}->set_from_pixbuf(create_pic($pic));			
		}
	}

	# refresh top label
	my $uid = nvl($user_attrs->{uid}->{cur_val});
	my $cn = nvl($user_attrs->{cn}->{cur_val});
	my $new_user_name = "$uid ($cn)";
	if ($user_name->get_text() ne $new_user_name) {
		$user_name->set_text("$uid ($cn)");
	}

	# refresh buttons
	set_user_changed($chg);
}


sub set_user_changed
{
	my $chg = shift;
	return if $chg == $changed;
	$changed = $chg;
	$btn_apply->set_sensitive($chg);
	$btn_revert->set_sensitive($chg);
	$btn_refresh->set_sensitive(!$chg);
	$btn_add->set_sensitive(!$chg);
	$btn_delete->set_sensitive(!$chg);
	$user_list->set_sensitive(!$chg);
}


sub gui_exit
{
	if ($changed) {
		my $resp = message_box('question', 'yes-no', "Выйти и потерять изменения ?");
		return 1 if $resp ne 'yes';
		$changed = 0;
	}
	user_unselect();
	Gtk2->main_quit;
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
	$frame = Gtk2::Frame->new("Атрибуты");
	$frame->add($tabs);
	$vbox->pack_start($frame, 1, 1, 0);

	for (@user_gui_attrs) {
		my ($tab_name, @tab_attrs) = @$_;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, $tab_name);
		$scroll->set_policy('automatic', 'automatic');
		$scroll->set_border_width(0);

		my $abox = Gtk2::Table->new($#tab_attrs + 1, 3);
		$scroll->add_with_viewport($abox);

		for my $row (0 .. $#tab_attrs) {
			my $gui_attr = $tab_attrs[$row];
			my ($type, $attr, $text) = @$gui_attr;
			my $label = Gtk2::Label->new($text);
			$label->set_justify('left');
			my $entry = Gtk2::Entry->new;
			my $bulb = Gtk2::Image->new;
			$abox->attach($bulb, 0, 1, $row, $row+1, [], [], 1, 1);
			$abox->attach($label, 1, 2, $row, $row+1, [], [], 1, 1);
			$abox->attach($entry, 2, 3, $row, $row+1, [ 'fill', 'expand' ], [], 1, 1);
			$user_attrs->{$attr} = $entry->{user_attr} = {
				type => $type,
				attr => $attr,
				entry => $entry,
				bulb => $bulb,
			};
			$entry->signal_connect(key_release_event => \&user_entry_attr_changed)
		}
	}

	my $buttons = create_button_bar(
		[],
		[ "Сохранить", "apply.png", \&user_save, \$btn_apply ],
		[ "Отменить", "revert.png", \&user_revert,\$btn_revert ],
		[ "Заполнить", "fill.png", \&user_fill, \$btn_fill ],
	);
	$vbox->pack_end($buttons, 0, 0, 2);
	
	return $vbox;
}


sub create_user_list
{
	my @user_list_titles = ('Идентификатор', 'Полное имя');

	$user_list = Gtk2::TreeView->new;
	$user_list->set_rules_hint(1);
	$user_list->get_selection->set_mode('single');
	$user_list->set_size_request(300, 300);

	my $model = Gtk2::TreeStore->new(qw(Glib::String Glib::String));
	$user_list->set_model($model);

	for my $k (0 .. $#user_list_titles) {
		my $renderer = Gtk2::CellRendererText->new;
		$renderer->set(xalign => 0.0);
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


# ======== main ========

sub gui_main
{
	($pname = $0) =~ s/^.*\///;
	my %opts;
	my $cmd_ok = getopts("Dhv:", \%opts);
	die "usage: $pname [-v log_level]\n" if !$cmd_ok || $opts{h};

	configure(@{$config{config_files}});
	my $level = $config{log_level} if defined $config{log_level};
	$level = $opts{v} if $opts{v};
	dump_config() if $opts{D};

	init_log($level);
	connect_all();

	Gtk2->init;
	my $gtkrc;
	Gtk2::Rc->parse($gtkrc) if defined $gtkrc;
	$main_win = Gtk2::Window->new("toplevel");

	my $tabs = Gtk2::Notebook->new;
	$tabs->set_tab_pos("top");

	my $hpane = Gtk2::HPaned->new;
	$hpane->add1(create_user_list());
	$hpane->add2(create_user_desc());
	my $buttons = create_button_bar (
		[ "Добавить", "add.png", \&user_add, \$btn_add ],
		[ "Удалить", "delete.png", \&user_delete, \$btn_delete ],
		[ "Обновить", "refresh.png", \&users_refresh, \$btn_refresh ],
		[],
		[ "Выйти", "exit.png", \&gui_exit ],
	);
	my $vbox = Gtk2::VBox->new;
	$vbox->pack_start($hpane, 1, 1, 1);
	$vbox->pack_end($buttons, 0, 0, 1);
	$tabs->append_page($vbox, " Пользователи ");

	$vbox = Gtk2::VBox->new;
	$tabs->append_page($vbox, " Группы ");
	$hpane = Gtk2::HPaned->new;
	$vbox->pack_start($hpane, 1, 1, 1);
	$hpane->add1(Gtk2::Label->new(""));
	$hpane->add2(Gtk2::Label->new(""));

	$main_win->add($tabs);
	user_unselect();

	$main_win->signal_connect("delete_event" => \&gui_exit);
	$main_win->signal_connect("destroy"      => \&gui_exit);
	$main_win->set_default_size(900, 600);
	$main_win->show_all;
	$main_win->window->set_icon(undef,
							create_pic("tree.png")->render_pixmap_and_mask(1));

	users_refresh();

	Gtk2->main;

	disconnect_all();
}

gui_main();

