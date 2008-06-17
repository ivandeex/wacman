#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use strict;
use warnings;
no warnings 'utf8';
use utf8;
use open ':utf8';
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


# ======== config =========


use constant NO_EXPIRE => '9223372036854775807';
use constant SAM_USER_OBJECT => hex('0x30000000');
use constant ADS_UF_NORMAL_ACCOUNT => hex(0x00000200);

my %servers = (
	win => {
		uri		=>	'ldaps://xxx.winsrv.vpn',
		user	=>	'cn=syncadmin,cn=builtin,dc=gclimate,dc=local',
		passfile=>	'/etc/ldap-refresh.secret',
		base	=>	'dc=gclimate,dc=local',
		debug	=>	0,
		convert	=>	0,
	},
	srv => {
		uri		=>	'ldaps://xxx.el4.vihens.ru',
		user	=>	'cn=dirman',
		passfile=>	'/etc/ldap-refresh.secret',
		base	=>	'dc=vihens,dc=ru',
		debug	=>	0,
		convert	=>	1,
	}
);

my %config = (
	config_files		=>	[ '/etc/ldap-refresh.cfg', '~/.ldap-refresh.cfg' ],
	force				=>	0,
	agreement_base		=> "cn=mapping tree, cn=config",	
	agreement_types		=> [
			"nsDSWindowsReplicationAgreement",
			"nsds5replicationagreement",
		],
	skel_dir			=>	'/etc/skel',
	xinstall_command	=>	'/usr/bin/sudo -S /usr/local/sbin/xinstall',
	user_class			=>	'person',
	poll_interval		=>	5,
	log_file			=>	'ldap-refresh.log',
	#log_file			=>	'/var/log/ldap-refresh.log',
	pid_file			=>	'ldap-refresh.pid',
	#pid_file			=>	'/var/run/ldap-refresh.pid',
	log_level			=>	'info',

	ad_retry_count		=>	3,
	ad_can_create		=>	1,
	ad_initial_pass		=>	'123qweASD',
	unix_user_classes	=>	[ qw(top person organizationalPerson inetOrgPerson posixAccount shadowAccount ntUser) ],	
	ad_user_classes		=>	[ qw(top user person organizationalPerson) ],	
	ad_user_category	=>	'Person.Schema.Configuration',
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
	ntUserCreateNewAccount => 'true',
	ntUserDeleteAccount => 'true',
	ntUserHomeDirDrive => 'H',
	#ntUserCodePage => pack('c',0),
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

# ======== Logging ========


my $log;

sub init_log ($$$)
{
	my ($level, $to_stdout, $to_file) = @_;
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
	if (!defined($to_stdout) && !defined($to_file)) {
		$to_stdout = 1;
		$to_file = 0;
	}
	if (!defined($to_file)) {
		$to_file = 0;
	}
	$log = Log::Log4perl->get_logger("refresh");
	my $layout = Log::Log4perl::Layout::PatternLayout->new('%d %c %p: %m%n');
	if ($to_file) {
		my $file_appender = Log::Log4perl::Appender->new(
					"Log::Log4perl::Appender::File",
					name      => "filelog",
					filename  => $config{log_file});
		$file_appender->layout($layout);
		$log->add_appender($file_appender);
	}
	if ($to_stdout) {
		my $stdout_appender =  Log::Log4perl::Appender->new(
					"Log::Log4perl::Appender::Screen",
					name      => "screenlog",
					stderr    => 0);
		$stdout_appender->layout($layout);
  		$log->add_appender($stdout_appender);
	}
	$log->level($level);
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

sub ldap_attr2disp
{
	return ldap_convert_attr($_[0], $_[1], 0);
}

sub ldap_disp2attr
{
	return ldap_convert_attr($_[0], $_[1], 1);
}


sub ldap_print_entry
{
	my ($entry, $atts) = @_;
	my ($attr, %atts);
	$atts = '*' unless defined $atts;
	if ($atts ne '*') {
		for $attr (split(/,/, $atts)) {
			$atts{$attr} = 1;
		}
	}
	my $fmt = "%28s: [%s] ";
	print "\n".sprintf($fmt,"dn",$entry->dn)."\n";
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
	return defined($_[0]) ? $_[0] : '';
}


sub convert_entry_full
{
	my $uen = shift;
	my $wen = Net::LDAP::Entry->new;
	my $uid = $uen->get_value("uid");
	my $cn = $uen->get_value("cn");
	my $mail = $uen->get_value("mail");
	my $ad_domain = $config{ad_domain};
	(my $nis_domain = $ad_domain) =~ s/\..*//;
	my $ad_user_cont = $config{ad_user_container};
	my $dc_domain = path2dn($ad_domain, 'DC');
	my $dn = "CN=$uid,".path2dn($ad_user_cont).",$dc_domain";
	$mail = $uid.'.'.$config{unix_domain};
	$wen->dn($dn);
	my $fld;
	for $fld (keys %ad_fields_from_unix) {
		my $ufld = $ad_fields_from_unix{$fld};
		$ufld = $fld unless $ufld;
		my $val = $uen->get_value($ufld);
		$wen->add($fld, $val) if defined $val;
	}
	for $fld (keys %ad_fields_const) {
		$wen->add($fld, $ad_fields_const{$fld});
	}
	for my $grp (@{$config{windows_groups}}) {
		$wen->add('memberOf' => path2dn($grp).",$dc_domain");
	}
	$wen->add('objectCategory' => path2dn($config{ad_user_category}).",$dc_domain");
	$wen->add('ufn' => disp2attr('ufn', "$uid , $ad_user_cont, $ad_domain"));
	$wen->add('msSFU30NisDomain' => $nis_domain);

	my %path_subst = (
		'SERVER'	=>	$config{home_server},
		'USER'		=>	$uid,
	);
	$wen->add('homeDirectory' => subst_path($config{ad_home_dir}, %path_subst));
	$wen->add('scriptPath' => subst_path($config{ad_script_path}, %path_subst));
	$wen->add('profilePath' => subst_path($config{ad_profile_path}, %path_subst));
	$wen->add('homeDrive' => $config{home_drive});
	return $wen;
}


# ======== massage ========


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
		$log->info("massage id $id ...");
		my $ua = massage_unix_account($id);
		if (defined $ua) {
			massage_home_dir($ua);
			# at this point we need to tell FDS to synchronize
			massage_windows_account($ua)
		}
	}
}


my $next_uidn;

sub get_next_uidn
{
	if (defined($next_uidn) && $next_uidn > 0) {
		return $next_uidn;
	}
	$next_uidn = 0;
	my $res = ldap_search(	$srv,
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
		$log->error("massage_user($id): ".$res->error);
		return;
	}
	my $ua = $res->pop_entry;
	if (massage_unix_account_entry($ua)) {
		$res = ldap_update($srv, $ua); 
		my $uid = $ua->get_value('uid');
		$log->info("changed: uid=($uid), ret=(".$res->error.")");
	}
	return $ua;
}


sub massage_unix_account_entry
{
	my $ua = shift;

	# read all scalar attributes
	my $uchange = 0;
	my $uid = $ua->get_value('uid');
	my $cn = $ua->get_value('cn');

	# add the required classes
	my (%classes);
	for ($ua->get_value('objectClass')) { $classes{$_} = $classes{lc} = 1; }
	for my $class (@{$config{unix_user_classes}}) {
		my $lclass = lc($class);
		unless (defined($classes{$class}) || defined($classes{$lclass})) {
			$ua->add(objectClass => $class);
			$log->info("$uid($cn): add class $class");
			$uchange++;
		}
	}

	# assign next available UID number
	unless (ldap_has_attr($ua, 'uidNumber')) {
		$uchange++ if ldap_cond_set($ua, 'uidNumber', get_next_uidn());
	}

	# names
	unless (ldap_has_attr($ua, 'cn')) {
		my $gn = $ua->get_value('givenName');
		my $sn = $ua->get_value('sn');
		$gn = '' unless defined $gn;
		$sn = '' unless defined $sn;
		my $blank = '';
		$blank = ' ' if $sn || $gn;
		$cn = "$gn$blank$sn";
		$uchange++ if ldap_cond_set($ua, 'cn', $cn);
	}

	unless (ldap_has_attr($ua, 'uid')) {
		my $gn = $ua->get_value('givenName');
		my $sn = $ua->get_value('sn');
		$uid = lc(substr($gn, 0, 1) . $sn);
		$uid =~ tr/абвгдежзийклмнопрстуфхцчшщъыьэюя/abvgdewzijklmnoprstufhc4wwxyxeua/;		
		$uid =~ tr/АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ/abvgdewzijklmnoprstufhc4wwxyxeua/;
		$uid =~ tr/[A-Z]/[a-z]/;
		$uid =~ tr/0-9a-z/_/cs;
		$uchange++ if ldap_cond_set($ua, 'uid', $uid);
	}

	# mail
	$uchange++ if ldap_cond_set($ua, 'mail', $uid.'@'.$config{unix_domain});

	# home directory
	$uchange++ if ldap_cond_set($ua, 'homeDirectory', "/home/$uid");

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
					subst_path($config{ad_home_dir}, %path_subst));
	$uchange++ if
		ldap_cond_set($ua, 'ntUserProfile',
					subst_path($config{ad_profile_path}, %path_subst));
	$uchange++ if
		ldap_cond_set($ua, 'ntUserScriptPath',
					subst_path($config{ad_script_path}, %path_subst));
	$uchange++ if
		ldap_cond_set($ua, 'ntUserDomainId', $uid);

	return $uchange;
}


my @ad_user_groups;

sub massage_windows_account
{
	my $ua = shift;
	my $uid = $ua->get_value('uid');
	my $cn = $ua->get_value('cn');

	$log->info("massage windows $uid ($cn) ...");
	my $filter = "(&(objectClass=user)(cn=$cn))";
	my ($res, $wa);
	my $wchange = 0;
	my $uchange = 0;
	my $base = $win->{CFG}->{base};
	my $attrs = [ '*', 'unicodePwd' ];
	my $ok = 0;
	my $created = 0;
	my $unipwd;

	for my $i (1 .. $config{ad_retry_count}) {
		$res = ldap_search( $win, base => $base, filter => $filter, attrs => $attrs );
		$wa = $res->pop_entry;
		$ok = (!$res->code && defined($wa));
		last if $ok;
		$log->warn("retry $i on windows user ($cn) for uid ($uid) ...");
		sleep 1;
	}

	$log->info("found windows $uid ($cn) ".$wa->dn." ...") if $ok;
		
	# still need full resynchronization here !
	unless ($ok) {
		$log->error("cannot find windows user ($cn) for uid ($uid) ...");
		return unless $config{ad_can_create};

		# detect whether wanna create a new entry
		if ($config{ad_can_create} > 2) {
			$created++;
		} elsif (ldap_has_attr($ua, 'gecos')
				&& $ua->get_value('gecos') eq 'new') {
			$ua->replace('gecos' => 'replicated');
			$created++;
			$uchange++;
		} elsif (ldap_has_attr($ua, 'telephoneNumber')
				&& $ua->get_value('telephoneNumber') eq 'new') {
			$ua->replace('telephoneNumber' => '');
			$created++;
			$uchange++;
		}
		return unless $created;
		
		# really create
		$log->info("will create entry ($cn) for uid ($uid) ...");
		my $ad_dc_domain = path2dn($config{ad_domain},'dc');
		my $dn = "cn=$cn,".path2dn($config{ad_user_container}).",$ad_dc_domain";
		$wa = Net::LDAP::Entry->new();
		$wa->dn($dn);
		$wa->add(objectClass => $config{ad_user_classes});
		$log->info("created windows user: $dn");
		$log->info("$cn: object classes: ".join(',',@{$config{ad_user_classes}}).")");
		$created++;
		$wchange++;
		ldap_cond_set($wa, 'cn', $cn);
		ldap_cond_set($wa, 'instanceType', 4);
		my $obj_category = path2dn($config{ad_user_category}).",$ad_dc_domain";
		ldap_cond_set($wa, 'objectCategory', $obj_category);

		if (defined($config{ad_initial_pass})) {
			my $unipwd = "";
			map { $unipwd .= "$_\000" } split(//, "\"$config{ad_initial_pass}\"");
			ldap_cond_set($wa, 'unicodePwd', $unipwd); # FIXME! also need to change unix pwd
		}

		ldap_cond_set($wa, 'userAccountControl', 512); # FIXME! #ADS_UF_NORMAL_ACCOUNT);
	}

	my $ad_principal = $uid.'@'.$config{ad_domain};
	$wchange++ if ldap_cond_set($wa, 'userPrincipalName', $ad_principal);	

	# copy fields from unix
	my $wattr;
	for $wattr (sort keys %ad_fields_from_unix) {
		next unless $wattr;
		my $uattr = $ad_fields_from_unix{$wattr};
		my $f = $config{force};
		$config{force} = 0;
		my $ok = ($uattr && ldap_has_attr($ua, $uattr));
		$config{force} = $f;
		next unless $ok;
		$wchange++ if ldap_cond_set($wa, $wattr, $ua->get_value($uattr));
	}

	# constant fields
	for $wattr (sort keys %ad_fields_const) {
		$wchange++ if ldap_cond_set($wa, $wattr, $ad_fields_const{$wattr});
	}

	# update on server
	if ($wchange) {
		$res = ldap_update($win, $wa); 
		my $ret = $res->error;
		chop $ret;
		chomp $ret;
		$log->info("changed: cn=($cn), ret=($ret)");

		ldap_update($srv, $ua) if $uchange;
	}

	#$res = $win->modify($wa->dn, replace => { "unicodePwd" => $unipwd });

	# refresh list of groups
	if ($#ad_user_groups < 0) {
		$filter = join('', map("(cn=$_)", @{$config{ad_user_groups}}));
		$filter = "(&(objectClass=group)(|$filter))";
		$res = ldap_search( $win, base => $base, filter => $filter );
		@ad_user_groups = $res->entries;
	}

	# add to required groups
	for my $user_group (@ad_user_groups) {
		$log->debug("user_group: ". $user_group->dn);
		my %members;
		for ($user_group->get_value('member')) { $members{$_} = 1 }
		# FIXME! performed twice!
		unless (defined $members{$wa->dn}) {
			$log->info("adding ($cn) to ".$user_group->dn);
			$user_group->add( member => $wa->dn );
			$user_group->update($win);
		}
	}

}


# ======== home directory ========


sub massage_home_dir ($)
{
	my ($ua, $gotta_ask) = @_;
	my $home = $ua->get_value('homeDirectory');
	$log->info("massage home $home ...");
	return 0 if -d $home;
	return 1 if $gotta_ask;
	$log->info("$home: gotta create");
	my $skel = $config{skel_dir};
	my $xinstall = $config{xinstall_command};
	my $uid = $ua->get_value('uidNumber');
	my $gid = $ua->get_value('gidNumber');
	my $stdall = `$xinstall "$uid" "$gid" "$skel" "$home" 2>&1`;
	$log->debug("xinstall: [$stdall]");
	return 1;
}


# ======== poll for changes ========

my @agreements;
my $last_stamp;

sub refresh_agreements {
	my $filter = '(|'.join('', map("(objectClass=$_)", @{$config{agreement_types}})).')';
	my $res = ldap_search( $srv,
					base => $config{agreement_base}, scope => 'sub',
					filter => $filter, attrs => [ 'dn' ] );
	@agreements = map { $_->dn } $res->entries;
	$log->debug("agrs=".join(', ', @agreements));
}

sub check_agreement_stamps
{
	if ($#agreements < 0) {
		refresh_agreements()
	}
	my $last;
	for (@agreements) {
		my $res = ldap_search( $srv, base => $_, filter => "(objectClass=*)" );
		next if $res->code;
		my $stamp = $res->pop_entry->get_value('nsds5replicaLastUpdateEnd');
		$last = $stamp
			if !defined($last) || $stamp gt $last;
	}
	return $last;
}

sub check_account_stamps
{
	my $last;
	my $user_class = $config{user_class};
	my $res = ldap_search( $srv, base => $srv->{CFG}->{base},
							filter => "(&(objectClass=$user_class))",
							attrs => [ 'modifyTimestamp' ] );
	for my $ua ($res->entries) {
		my $stamp = $ua->get_value('modifyTimestamp');
		$log->trace("stamp: $stamp  dn: ".$ua->dn);
		$last = $stamp
			if !defined($last) || $stamp gt $last;
	}
	return $last;
}

sub is_fresh ($)
{
	my $last = shift;
	my $changed = 0;
	if (defined $last) {
		if (defined $last_stamp) {
			if ($last_stamp lt $last) {
				$last_stamp = $last;
				$changed = 1;
			}
		} else {
			$last_stamp = $last;
			$changed = 1;
		}
	}
	$last = '' unless defined $last;
	$log->debug("last=$last changed=$changed");
	return $changed;
}

# ======== configuring ========

sub configure
{
	for my $file (@_) {
		next unless $file;
		$file =~ s/^~\//$ENV{HOME}\//;
		#print "trying file $file\n";
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
		if ($val =~ /^ARRAY\(\S+\)$/) {
			$val = '[ '.join(', ',map("\"$_\"",@$val)).' ]';
		} else {
			$val = '"'.$val.'"';
		}
		print "config{$_} = $val\n";
	}
}


# ======== daemon mode ========


sub write_pid
{
	return unless $config{pid_file};
	open(PID_FILE, "> $config{pid_file}") || return;
	print PID_FILE $$;
	close PID_FILE;
}


sub check_for_updates
{
	my $changed = 0;
	#$changed += is_fresh(check_agreement_stamps());
	$changed += is_fresh(check_account_stamps());
	return $changed;
}


sub daemon_poll
{
	while (1) {
		if (check_for_updates()) {
			$log->info("last=$last_stamp");
			massage_accounts();
		}
		sleep $config{poll_interval};
	}
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
	$ent->update($srv);
	undef $next_uidn;
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
			next if /^\s*()$/;
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
	} else {
		if ($config{force}) {
			return 0;
		}
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
	my $gui_mode = defined($record->{user_attr}) ? 1 : 0;
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
			$log->info("($short_dn): [$attr] := ($value)")
				unless $gui_mode;
		}
		$ret = 1;
	} else {
		$record->add($attr => $value);
		$log->info("($short_dn): [$attr] += ($value)")
			unless $gui_mode;
		$ret = 2;
	}
	return $ret;
}


# ======== gui mode ========


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


use FindBin qw[$Bin];
use Cwd 'abs_path';


my $pic_home = abs_path("$Bin/images");
my $changed;
my ($btn_apply, $btn_revert, $btn_fill);
my ($btn_add, $btn_delete, $btn_refresh);
my ($user_list, $user_name);
my ($user_attrs, @user_attr_entries, $user_attr_tabs);
my ($orig_acc, $edit_acc);


sub user_apply
{
}


sub user_revert
{
}


sub user_fill
{
}


sub user_add
{
	return if user_unselect();
	my $model = $user_list->get_model;
	my $node = $model->append(undef);
	$model->set($node, 0, '', 1, '');
	#$user_attr_entries[0]->{entry}->grab_focus;
	my $path = $model->get_path($node);
	$user_list->set_cursor($path);
	user_select($path, 0);
}


sub user_delete
{
}


sub users_refresh
{
	return if user_unselect();
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
}


sub user_unselect
{
	return 0 unless defined $user_name;
	$user_name->set_text('');
	for my $e (@user_attr_entries) {
		$e->{entry}->set_text('');
		$e->{bulb}->set_image(create_image('empty.png'));
	}
	$btn_apply->set_sensitive(0) ;
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
	my $iter = $model->get_iter($path);
	my $uid = $model->get($iter, 0);
	my $cn = $model->get($iter, 1);
	return unless defined $uid;

	$user_name->set_text("$uid ($cn)");
	$btn_fill->set_sensitive(1);

	my ($ua, $e);
	@user_attr_entries = values(%$user_attrs);
	if ($uid eq '') {
		$ua = Net::LDAP::Entry->new;
		for $e (@user_attr_entries) {
			$ua->add($e->{attr} => '');
		}
	} else {
		my $user_class = $config{user_class};
		my $res = ldap_search(	$srv,
						base => $srv->{CFG}->{base},
						filter => "(&(objectClass=$user_class)(uid=$uid))" );
		if ($res->code || scalar($res->entries) == 0) {
			$log->info("cannot find uid [$uid]");
			return undef;
		}
		$ua = $res->pop_entry;
	}
	$orig_acc = $ua;
	undef $edit_acc;
	$edit_acc = $ua->clone;

	for $e (@user_attr_entries) {
		my $value = nvl($ua->get_value($e->{attr}));
		$e->{entry}->set_text($value);
		$e->{new_val} = $e->{cur_val} = $e->{old_val} = $value;
		$e->{state} = $value eq '' ? 'empty' : 'orig'; 
		my $pic =  $state2pic{$e->{state}};
		$pic = 'empty.png' unless defined $pic;
		$e->{bulb}->set_image(create_image($pic));
	}

	$btn_fill->set_sensitive(1);
	$btn_delete->set_sensitive(1);
	$user_attr_tabs->set_current_page(0);
}


sub user_entry_attr_changed
{
	my ($entry0, $event0) = @_;
	my $e0 = $entry0->{user_attr};
	return undef unless $e0;
	my $e;

	$e0->{new_val} = nvl($e0->{entry}->get_text());
	return undef if $e0->{cur_val} eq $e0->{new_val};

	# read values
	for $e (@user_attr_entries) {
		$e->{old_state} = $e->{state};
		$edit_acc->replace($e->{attr}, $e->{new_val});
	}

	# calculate calculatable fields
	$e0->{state} = 'user';
	$edit_acc->{user_attr} = $user_attrs;
	my $changed = massage_unix_account_entry($edit_acc);

	# analyze results
	for $e (@user_attr_entries) {
		my $val = nvl($edit_acc->get_value($e->{attr}));
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
		$e->{entry}->set_text($val);
		$e->{state} = $state;
	}

	# change indication
	for $e (@user_attr_entries) {
		if ($e->{state} ne $e->{old_state}) {
			my $pic =  $state2pic{$e->{state}};
			$pic = 'empty.png' unless defined $pic;
			$e->{bulb}->set_image(create_image($pic));			
		}
	}

	# change top label
	my $uid = nvl($user_attrs->{uid}->{cur_val});
	my $cn = nvl($user_attrs->{cn}->{cur_val});
	my $new_user_name = "$uid ($cn)";
	if ($user_name->get_text() ne $new_user_name) {
		$user_name->set_text("$uid ($cn)");
	}

	return undef;
}


sub gui_exit
{
	return if user_unselect();
	Gtk2->main_quit;
}


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


sub create_image ($)
{
	my $file = $_[0];
	my $pic = create_pic($file);
	return undef unless defined $pic;
	return Gtk2::Image->new_from_pixbuf($pic);
}


sub create_button
{
	my ($text, $pic, $action, $owner_box) = @_;
	my $button = Gtk2::Button->new_with_label($text);
	$button->set_image(create_image($pic)) if $pic;		
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
			my $bulb = Gtk2::Button->new;
			$bulb->set_relief('none');
			$bulb->set_image(create_image('empty.png'));
			$bulb->can_focus(0);
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
		[ "Сохранить", "apply.png", \&user_apply, \$btn_apply ],
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

	users_refresh();

	$user_list->signal_connect(cursor_changed => \&user_select);

	return $frame;
}


sub start_gui()
{
	Gtk2->init;
	my $gtkrc;
	Gtk2::Rc->parse($gtkrc) if defined $gtkrc;
	my $win = Gtk2::Window->new("toplevel");

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

	$win->add($tabs);
	user_unselect();

	$win->signal_connect("delete_event" => \&gui_exit);
	$win->signal_connect("destroy"      => \&gui_exit);
	$win->set_default_size(900, 600);
	$win->show_all;
	my $pic = create_pic("tree.png");
	$win->window->set_icon(undef, $pic->render_pixmap_and_mask(1));
	Gtk2->main;
}

# ======== main ========

sub main
{
	($pname = $0) =~ s/^.*\///;
	my %opts;
	my $cmd_ok = getopts("fgndDchv:", \%opts);
	die <<USAGE
usage: $pname [-f] [-v level] { -n [user...] | -d | -c }
	-f		force updates
	-v		set log level
	-n		normal mode, update all or listed users
	-d		daemon mode
	-g		GUI mode
	-c		CGI mode (default), not yet implemented
USAGE
		if !$cmd_ok || $opts{h};

	configure(@{$config{config_files}});
	$config{force} = 1 if $opts{f};
	my $level = $config{log_level} if defined $config{log_level};
	$level = $opts{v} if $opts{v};
	dump_config() if $opts{D};

	if ($opts{g}) {
		# gui mode
		init_log($level, 1, 0);
		connect_all();
		start_gui();
		disconnect_all();
	} elsif ($opts{n}) {
		# normal mode
		my @args;
		map { push @args, $_ unless $_ =~ /^\-/ } @ARGV;
		init_log($level, 1, 0);
		connect_all();
		massage_accounts(@args);
		disconnect_all();
	} elsif ($opts{d}) {
		# daemon mode
		init_log($level, 0, 1);
		write_pid();
		connect_all();
		daemon_poll();
		disconnect_all();
	} else {
		# 	cgi_mode();
		die "CGI mode not defined (or use -h for help)\n";
	}
	$log->info("done");
}

main();

