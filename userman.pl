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
use Digest::MD5;
use Digest::SHA1;
use Net::Telnet ();
use threads;
use threads::shared;

use FindBin qw[$Bin];
use Cwd 'abs_path';

my ($pname, $main_wnd, %install);

my ($btn_usr_apply, $btn_usr_revert, $btn_usr_add, $btn_usr_delete, $btn_usr_refresh);
my ($user_list, $user_attr_frame, $user_attr_tabs, $user_name, $user_obj);

my ($btn_grp_apply, $btn_grp_revert, $btn_grp_add, $btn_grp_delete, $btn_grp_refresh);
my ($group_list, $group_attr_frame, $group_name, $group_obj);

my ($btn_mgrp_apply, $btn_mgrp_revert, $btn_mgrp_add, $btn_mgrp_delete, $btn_mgrp_refresh);
my ($mailgroup_list, $mailgroup_attr_frame, $mailgroup_name, $mailgroup_obj);

my ($next_uidn, $next_gidn, $next_telnum);
my ($domain_intercept, $server_intercept);

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
	cgp => { disable => 1 },	# CommuniGate Pro
	cli => { disable => 1 },	# CommuniGate Pro - CLI interface
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
	cgp_user_classes	=>	'top,person,organizationalPerson,inetOrgPerson,CommuniGateAccount',
	cgp_group_classes	=>	'top,person,organizationalPerson,inetOrgPerson,CommuniGateGroup',
	cgp_alias_classes	=>	'top,alias',
	cgp_intercept_opts	=>	'Access,Append,Login,Mailbox,Partial,Sent,Signal',
	cgp_buggy_ldap		=>	1,
	cli_timeout			=>	3,
	cli_idle_interval	=>	30,
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
		'Again password'=>	'Еще раз...',
		'Mail'			=>	'Почта',
		'User#'			=>	'Числовой ид.',
		'Group'			=>	'Группа',
		'Other groups'	=>	'Прочие группы',
		'Home directory'=>	'Домашний каталог',
		'Login shell'	=>	'Интерпретатор',
		'Drive'			=>	'Диск',
		'Profile'		=>	'Профиль',
		'Logon script'	=>	'Сценарий входа',
		'Telephone'		=>	'Телефон',
		'Fax number'	=>	'Номер факса',
		'Short number'	=>	'Короткий номер',
		'Common'		=>	'Основные',
		'Extended'		=>	'Дополнительно',
		'Manage Users'	=>	'Управление Пользователями',
		'User "%s" not found'	=>	'Не найден пользователь "%s"',
		'User "%s" not found: %s'	=>	'Пользователь "%s" не найден: %s',
		'Error reading list of Windows groups: %s'	=>	'Ошибка чтения списка Windows-групп: %s',
		'Error reading Windows group "%s" (%s): %s'	=>	'Ошибка чтения Windows-группы "%s" (%s): %s',
		'Error updating Windows-user "%s": %s'	=>	'Ошибка обновления Windows-пользователя "%s": %s',
		'Error updating mail account "%s" (%s): %s'	=>	'Ошибка обновления пользователя почты "%s" (%s): %s',
		'Error re-updating Unix-user "%s" (%s): %s'	=>	'Ошибка пере-обновления Unix-пользьвателя "%s" (%s): %s',
		'Error adding "%s" to Windows-group "%s": %s'	=>	'Ошибка добавления "%s" в Windows-группу "%s": %s',
		'Error saving user "%s" (%s): %s'	=>	'Ошибка сохранения пользователя "%s" (%s): %s',
		'Cannot change mail aliases for "%s": %s' => 'Ошибка изменения почтовых алиасов для "%s": %s',
		'Really revert changes ?'	=>	'Действительно откатить модификации ?',
		'Delete user "%s" ?'	=>	'Удалить пользователя "%s" ?',
		'Cancel new user ?'		=>	'Отменить добавление пользователя ?',
		'Error deleting Unix-user "%s" (%s): %s'	=>	'Ошибка удаления Unix-пользователя "%s" (%s): %s',
		'Error deleting Windows-user "%s" (%s): %s'	=>	'Ошибка удаления Windows-пользователя "%s" (%s): %s',
		'Error deleting mail account "%s" (%s): %s'	=>	'Ошибка удаления почтового пользователя "%s" (%s): %s',
		'Error creating mail alias "%s" for "%s": %s' => 'Ошибка создания почтового алиаса "%s" для "%s": %s',
		'Cannot display user "%s"'	=>	'Не могу вывести пользователя "%s"',
		'Cannot change password for "%s" on "%s": %s' => 'Не могу изменить пароль для "%s" на "%s": %s',
		'Exit and loose changes ?'	=>	'Выйти и потерять изменения ?',
		'Passwords dont match' => 'Введенные пароли не совпадают',
		'Password contains non-basic characters. Are you sure ?' => 'Пароль содержит символы из расширенного набора. Вы уверены ?',
		'Mail aliases should not contain non-basic characters' => 'В почтовых алиасах допустимы только символы базового набора',
		'Attributes'	=>	'Атрибуты',
		'Save'			=>	'Сохранить',
		'Revert'		=>	'Отменить',
		'Identifier'	=>	'Идентификатор',
		'Full name'	=>	'Полное имя',
		'Create'	=>	'Добавить',
		'Delete'	=>	'Удалить',
		'Refresh'	=>	'Обновить',
		'Exit'	=>	'Выйти',
		'Close'	=>	'Закрыть',
		' Users '	=>	' Пользователи ',
		' Groups '	=>	' Группы ',
		' Mail groups '	=>	' Почтовые группы ',
		'Group name'	=>	'Название группы',
		'Group number'	=>	'Номер группы',
		'Description'	=>	'Описание',
		'Members'		=>	'Члены группы',
		'Principal name'=>	'Принципал',
		'Mail aliases'	=>	'Почтовые алиасы',
		'Mail groups'	=>	'Почтовые группы',
		'Domain Intercept'	=>	'Слеж. за доменом',
		'User Intercept'	=>	'Слеж. за пользователем',
		'Real user id'	=>	'Реальный ид. пользователя',
		'Real group id'	=>	'Реальный ид. группы',
		'Error saving group "%s": %s'	=>	'Ошибка сохранения группы "%s": %s',
		'Cancel new group ?'	=>	'Отменить добавление группы ?',
		'Delete group "%s" ?'	=>	'Удалить группу "%s"',
		'Error deleting group "%s": %s'	=> 'Ошибка удаления группы "%s": %s',
		'Cannot display group "%s"'	=>	'Не могу отобразить группу "%s"',
		'Groups not found: %s' => 'Группы не найдены: %s',
		'Error saving mail group "%s": %s' => 'Ошибка сохранения почтовой группы "%s": %s',
		'Cancel new mail group ?' => 'Отменить создание почтовой группы ?',
		'Delete mail group "%s" ?' => 'Удалить почтовую группу "%s" ?',
		'Error deleting mail group "%s": %s' => 'Ошибка удаления почтовой группы "%s": %s',
		'Cannot display mail group "%s"' => 'Не могу отобразить почтовую группу "%s"',
		'This object name is reserved' => 'Этот идентификатор зарезервирован. Используйте другой.',
		'Cannot delete reserved object' => 'Этот объект нельзя удалить. Он зарезервирован.',
		'Connecting to "%s" ...' => 'Подключаюсь к "%s" ...',
	},
);


my %all_attrs = (
	########## user ##########
	user => {
		dn => {
			type => 'dn',
			ldap => 'uni',
			label => 'UNIX DN',
			readonly => 1,
		},
		ntDn => {
			type => 'dn',
			ldap => 'ads',
			label => 'Windows DN',
			readonly => 1,
		},
		cgpDn => {
			type => 'dn',
			ldap => 'cgp',
			label => 'CGP DN',
			readonly => 1,
		},
		objectClass => {
			type => 'class',
			ldap => { uni => 'objectClass' },
		},
		ntObjectClass => {
			type => 'class',
			ldap => { ads => 'objectClass' },
		},
		cgpObjectClass => {
			type => 'class',
			ldap => { cgp => 'objectClass' },
		},
		# posixAccount...
		givenName => {
			label => 'Name',
			ldap => 'uni,ads',
		},
		sn => {
			label => 'Second name',
			ldap => 'uni,ads,cgp',
		},
		cn => {
			label => 'Full name',
			ldap => 'uni,ads,cgp',
		},
		uid => {
			type => 'number',
			label => 'Identifier',
			ldap => 'uni,ads,cgp',
		},
		password => {
			type => 'pass',
			label => 'Password',
			ldap => { uni => 'userPassword', ads => 'unicodePwd', cgp => 'userPassword' },
		},
		password2 => {
			type => 'pass',
			label => 'Again password',
			ldap => { uni => 'userPassword', ads => 'unicodePwd', cgp => 'userPassword' },
			verify => 1,
		},
		mail => {
			label => 'Mail',
			ldap => 'uni,ads,cgp',
		},
		uidNumber => {
			label => 'User#',
			ldap => 'uni,ads',
		},
		gidNumber => {
			type => 'gid',
			label => 'Group',
			popup => 'gid',
			ldap => 'uni,ads',
		},
		moreGroups => {
			type => 'groups',
			label => 'Other groups',
			popup => 'groups',
			ldap => { uni => 'uidNumber' },
		},
		homeDirectory => {
			label => 'Home directory',
			ldap =>  { uni => '', ads => 'unixHomeDirectory' },
		},
		loginShell => {
			label => 'Login shell',
			ldap => 'uni,ads',
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
			type => 'ntprig',
			ldap => 'ads',
		},
		SecondaryGroups => {
			type => 'ntsecg',
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
		# CommuniGate Pro
		hostServer => {
			ldap => 'cgp',
		},
		storageLocation => {
			ldap => 'cgp',
			default => '*',
		},
		aliases => {
			type => 'aliases',
			label => 'Mail aliases',
			ldap => { cgp => 'uid' },
		},
		telnum => {
			type => 'none',		# (read/write via aliases)
			label => 'Short number',
			ldap => { cgp => 'uid' },
		},
		mailgroups => {
			type => 'mgroups',
			label => 'Mail groups',
			popup => 'mgroups',
			ldap => { cgp => 'uid' },
		},
		domainIntercept => {
			type => 'domainIntercept',
			label => 'Domain Intercept',
			checkbox => 1,
			ldap => { cgp => 'uid' },
		},
		userIntercept => {
			type => 'userIntercept',
			label => 'User Intercept',
			checkbox => 1,
			ldap => { cgp => 'uid' },
		},
		# Personal / Extended...
		telephoneNumber => {
			label => 'Telephone',
			ldap => 'uni,ads',
		},
		facsimileTelephoneNumber => {
			label => 'Fax number',
			ldap => 'uni,ads',
		},
		physicalDeliveryOfficeName => {
			ldap => 'uni,ads',
		},
		o => { ldap => 'uni,ads', },
		ou => { ldap => 'uni,ads', },
		label => { ldap => 'uni,ads', },
		real_uidn => {
			ldap => { uni => 'uidNumber' },
			type => 'real_uidn',
			label => 'Real user id',
			readonly => 1,
		},
		real_gidn => {
			ldap => { uni => 'gidNumber' },
			type => 'real_gidn',
			label => 'Real group id',
			readonly => 1,
		},
	},
	########## group ##########
	group => {
		objectClass => {
			type => 'class',
			ldap => 'uni',
		},
		dn => {
			type => 'dn',
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
			type => 'users',
			label => 'Members',
			popup => 'users',
			ldap => 'uni',
		},
	},
	########## mail group ##########
	mailgroup => {
		dn => {
			type => 'mailgroup',
			ldap => 'cli',
		},
		uid => {
			type => 'mailgroup',
			label => 'Group name',
			ldap => 'cli',
		},
		cn => {
			type => 'mailgroup',
			label => 'Description',
			ldap => 'cli',
		},
		groupMember => {
			type => 'mailgroup',
			label => 'Members',
			popup => 'mailusers',
			ldap => 'cli',
		},
		params => {
			type => 'mailgroup',
			ldap => 'cli',
			label => 'Params',
		},
	},
	########## mail alias (not for creation :) ) ##########
	alias => {
		objectclass => {
			type => 'class',
			ldap => 'cgp',
		},
		dn => {
			type => 'dn',
			ldap => 'cgp',
		},
		uid => {
			ldap => 'cgp',
		},
		aliasedObjectName => {
			ldap => 'cgp',
		},
	},
);


my %all_lc_attrs;


my %gui_attrs = (
	user => [
		[ 'Common',
			qw(	givenName sn cn uid mail password password2
				uidNumber gidNumber moreGroups homeDirectory loginShell
		) ],
		[ 'Windows',
			qw(	ntUserHomeDir ntUserHomeDirDrive
				ntUserProfile ntUserScriptPath
				userPrincipalName
		) ],
		[ 'Extended',
			qw(	telephoneNumber facsimileTelephoneNumber
				telnum aliases mailgroups
				domainIntercept userIntercept
				real_uidn real_gidn
		) ],
	],
	group => [
		[ 'Common',
			qw( cn gidNumber description memberUid
		) ],
	],
	mailgroup => [
		[ 'Common',
			qw( uid cn groupMember
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


my %string2bool = (
	'y'		=>	1,
	'yes'	=>	1,
	't'		=>	1,
	'true'	=>	1,
	'on'	=>	1,
	'ok'	=>	1,
	'1'		=>	1,
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
		my %modes = (config => 1);
		for (keys %servers) { $modes{$_} = 1; }
		while (<CONFIG>) {
			chop; chomp;
			next if /^\s*$/ || /^\s*\#/;
			if (/^\s*\[\s*(\S+)\s*\]\s*$/) {
				$mode = $1;
				log_error('incorrect section "%s" in %s: %s', $mode, $file, $_)
					unless $modes{$mode};
				next;
			} elsif (/^\s*(\S+)\s*=\s*(.*?)\s*$/) {
				my ($name, $val) = ($1, $2);
				if ($val =~ /^\'(.*?)\'$/ || $val =~ /^\"(.*?)\"$/) {
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
				if ($mode eq 'config') {
					$config{$name} = $val;				
				} else {
					$servers{$mode}{$name} = $val;
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


sub attribute_enabled ($$)
{
	my ($objtype, $name) = @_;
	return 0 if $objtype eq 'user' && $name eq 'domainIntercept';
	return 1;
}


sub setup_all_attrs ()
{
	for my $objtype (sort keys %all_attrs) {

		for my $cfg (values %servers) { $cfg->{attrhash}{$objtype} = {} }
		$all_lc_attrs{$objtype} = {};
		my $descs = $all_attrs{$objtype};

		for my $name (keys %$descs) {

			my $desc = $descs->{$name};
			$all_lc_attrs{$objtype}->{lc($name)} = $desc;

			$desc->{name} = $name;
			$desc->{type} = 'string' unless $desc->{type};
			$desc->{visual} = $desc->{label} ? 1 : 0;
			$desc->{label} = _T($desc->{label}) if $desc->{label};
			$desc->{readonly} = 0 unless $desc->{readonly};
			$desc->{verify} = 0 unless $desc->{verify};

			$desc->{popup} = 0 unless $desc->{popup};
			$desc->{checkbox} = 0 unless $desc->{checkbox};
			$desc->{popup} = 'yesno' if $desc->{checkbox};
			
			unless (defined $desc->{default}) {
				my $cfg_def = "default_value_${objtype}_${name}";
				if (defined $config{$cfg_def}) {
					$desc->{default} = $config{$cfg_def};
				}
			}

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
			$desc->{disable} = 1 unless attribute_enabled($objtype, $name);

			my $subs = $ldap_rw_subs{$desc->{disable} ? 'none' :$desc->{type}};
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


sub is_reserved_name ($)
{
	my $id = shift;
	for (split_list($config{reserved_names})) { return 1 if $_ eq $id }
	return 0;
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
	binmode(STDERR, ':utf8');
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


sub show_popup ($$%)
{
	my ($wnd, $popup_btn, %params) = @_;
	$wnd->set_transient_for($main_wnd);
	$wnd->set_position($params{center} ? 'center_on_parent' : 'mouse');
	# set_deletable() is not available in GTK+ 2.8 and older on Windows
	$wnd->set_deletable(0) if Gtk2->CHECK_VERSION(2, 9, 0);
	$wnd->set_modal(1);
	$wnd->signal_connect(delete_event	=> sub { destroy_popup($wnd, $popup_btn) });
	$wnd->signal_connect(destroy		=> sub { destroy_popup($wnd, $popup_btn) });
	$popup_btn->set_sensitive(0) if $popup_btn;
	$wnd->show_all;
	set_window_icon($wnd, "popup.png");
}


sub focus_attr ($$)
{
	my ($obj, $name) = @_;
	my $at = get_attr_node($obj, $name);
	$at->{entry}->grab_focus;
	$at->{tab_book}->set_current_page($at->{tab_page});
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


sub isascii ($)
{
	for (map { ord } split //, shift) { return 0 if $_ <= 32 || $_ >= 127 }
	return 1;
}


sub str2bool ($)
{
	return 0 unless defined $_[0];
	my $v = nvl(lc($_[0]));
	return 1 if $string2bool{$v};
	return 1 if ($v =~ /^(\d+)/) && $1 > 0;
	for my $k (keys %string2bool) {
		return 1 if substr($v, 0, length($k)) eq $k;
	}
	return 0;
}


sub bool2str ($)
{
	return str2bool($_[0]) ? 'Yes' : 'No';
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
	return $#_ < 0 ? '' : nvl(join ',', sort @_);
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


sub setup_attr ($$$)
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
		$at->{entry}->set_editable(!$desc->{disable} && !$desc->{readonly});
		if ($at->{type} eq 'pass') {
			$at->{entry}->set_visibility(0);
			$at->{entry}->set_invisible_char('*');
		}
		my $puptype = $desc->{popup};
		if ($puptype) {
			my $popup = create_button(undef, 'popup.png');
			$at->{popup} = $popup;
			my $sub;
			$sub = sub { create_yesno_chooser($at) } if $puptype eq 'yesno';
			$sub = sub { create_group_chooser($at) } if $puptype eq 'gid';
			$sub = sub { create_user_groups_editor($at) } if $puptype eq 'groups'; 
			$sub = sub { create_group_users_editor($at) } if $puptype eq 'users'; 
			$sub = sub { create_user_mail_groups_editor($at) } if $puptype eq 'mgroups';
			$sub = sub { create_mailgroup_users_editor($at) } if $puptype eq 'mailusers'; 
			log_error('unknown popup type "%s"', $puptype) unless $sub; 
			$popup->signal_connect(clicked => $sub);
			$popup->set_relief('none');
			$popup->can_focus(0);
		}
		if ($config{show_bulbs}) {
			$at->{bulb} = Gtk2::Image->new;
		}
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
	my $which = $param{orig} ? 'old' : 'val';
	return nvl($at->{$which});
}


sub set_attr ($$$)
{
	my ($obj, $name, $val, %param) = @_;

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


sub init_attr ($$$)
{
	my ($obj, $name, $val) = @_;
	my $at = get_attr_node($obj, $name);
	$val = nvl($val);
	if ($val eq '') {
		$at->{state} = 'empty';
	} else {
		$at->{val} = $at->{old} = $val;
		$at->{state} = 'orig';
	}
	$at->{entry}->set_text($at->{val}) if $at->{entry};
	return $at;
}


# ========  ldap readers / writers  ========


%ldap_rw_subs = (
	none    => [ \&ldap_read_none, \&ldap_write_none, \&ldap_write_none ],
	string  => [ \&ldap_read_string, \&ldap_write_string, \&ldap_write_none ],
	number  => [ \&ldap_read_string, \&ldap_write_string, \&ldap_write_none ],
	dn      => [ \&ldap_read_dn, \&ldap_write_dn, \&ldap_write_none ],
	class   => [ \&ldap_read_class, \&ldap_write_class, \&ldap_write_none ],
	pass    => [ \&ldap_read_pass, \&ldap_write_pass, \&ldap_write_pass_final ],
	gid     => [ \&ldap_read_unix_gidn, \&ldap_write_unix_gidn, \&ldap_write_none ],
	groups  => [ \&ldap_read_unix_groups, \&ldap_write_none, \&ldap_write_unix_groups_final ],
	users   => [ \&ldap_read_unix_members, \&ldap_write_unix_members, \&ldap_write_unix_members_final ],
	ntprig  => [ \&ldap_read_ad_pri_group, \&ldap_write_ad_pri_group, \&ldap_write_none ],
	ntsecg  => [ \&ldap_read_ad_sec_groups, \&ldap_write_none, \&ldap_write_ad_sec_groups_final ],
	aliases => [ \&ldap_read_aliases, \&ldap_write_none, \&ldap_write_aliases_final ],
	mgroups => [ \&ldap_read_mail_groups, \&ldap_write_none, \&ldap_write_mail_groups_final ],
	domainIntercept => [ \&cgp_read_domain_intercept, \&ldap_write_none, \&cgp_write_domain_intercept ],
	userIntercept => [ \&cgp_read_user_intercept, \&ldap_write_none, \&cgp_write_user_intercept ],
	mailgroup => [ \&ldap_read_none, \&ldap_write_none, \&ldap_write_none ],
	real_uidn => [ \&ldap_read_real_uidn, \&ldap_write_none, \&ldap_write_none ],
	real_gidn => [ \&ldap_read_real_gidn, \&ldap_write_none, \&ldap_write_none ],
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
	log_debug('ldap_write_class(%s): attr="%s" class="%s" changed=%d',
				$srv, $at->{name}, $val, $changed);
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


sub ldap_read_real_uidn ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	my @pwent = getpwnam(nvl($ldap->get_value('uid')));
	return nvl($pwent[2]);
}


sub ldap_read_real_gidn ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	my @pwent = getpwnam(nvl($ldap->get_value('uid')));
	return nvl($pwent[3]);
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
	return 0 if $val eq OLD_PASS || $at->{desc}->{verify};
	if ($srv eq 'ads') {
		# 'replace' works only for administrator.
		# unprivileged users need to use change(delete=old,add=new)
		$ldap->replace($name => encode_ad_pass($val));
		return 1;
	}
	return 0;
}


sub ldap_write_pass_final ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	return 0 if $val eq OLD_PASS || $at->{desc}->{verify};
	if ($srv eq 'uni') {
		my $conf = get_server($srv, 1);
		$ldap = $conf->{ldap};
		my $extop = $conf->{extop};
		unless (defined $extop) {
			$extop = $ldap->root_dse->supported_extension('1.3.6.1.4.1.4203.1.11.1');
			$extop = $extop ? 1 : 0;
			$conf->{extop} = $extop;
		}
		my $obj = $at->{obj};
		my $dn = get_attr($obj, 'dn');
		my $res;
		if ($extop) {
			# set_password() without 'oldpasswd' works only for administrator
			# ordinary users need to supply 'oldpasswd'
			$res = $ldap->set_password(user => $dn, newpasswd => $val);
		} else {
			# 'replace' works only for administrator.
			# unprivileged users need to use change(delete=old,add=new)
			$res = $ldap->modify($dn, replace => { $name => $val });
		}
		log_debug('change password on "%s": dn="%s" extop=%d attr=%s code=%d',
					$srv, $dn, $extop, $name, $res->code);
		if ($res->code) {
			message_box('error', 'close',
						_T('Cannot change password for "%s" on "%s": %s',
							$dn, $srv, $res->error));
			return 0;
		}
		return 1;
	}
	if ($srv eq 'cgp') {
		$ldap = get_server($srv, 1)->{ldap};
		my $obj = $at->{obj};
		my $dn = get_attr($obj, 'cgpDn');
		my $digest = "\x{02}{SHA}".Digest::SHA1::sha1_base64($val);
		log_debug('digest=%s', $digest);
		# 'replace' works only for administrator.
		# unprivileged users need to use change(delete=old,add=new)
		my $res = $ldap->modify($dn, replace => { $name => $digest });
		log_debug('change password on "%s": dn="%s" attr=%s code=%d',
					$srv, $dn, $name, $res->code);
		if ($res->code) {
			message_box('error', 'close',
						_T('Cannot change password for "%s" on "%s": %s',
							$dn, $srv, $res->error));
			return 0;
		}
		return 1;
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
	log_debug('will be %s\'ing unix user %d in group %d...', $action, $uidn, $gidn);
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
		log_info('%s unix user %d in group %d error: %s',
				$action, $uidn, $gidn, $res->error);
		$retval = $res->error;
	} else {
		log_debug('success %s\'ing unix user %d in group %d: [%s] -> [%s]...',
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


sub ldap_read_aliases ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	my $dn = nvl($ldap->dn);
	return '' if $dn eq '';
	my @aliases;
	my $telnum = '';
	my $old_telnum = get_attr($at->{obj}, 'telnum', orig => 1);
	for (ldap_search($srv, "(&(objectClass=alias)(aliasedObjectName=$dn))", ['uid'])->entries) {
		my $alias = $_->get_value('uid');
		if ($old_telnum eq '' && $telnum eq '' && $alias =~ /^\d{3}$/) {
			$telnum = $alias;
		} else {
			push @aliases, $alias;
		}
	}
	my $aliases = join_list @aliases;
	log_debug('read aliases: telnum="%s" aliases="%s"', $telnum, $aliases);
	init_attr($at->{obj}, 'telnum', $telnum) if $telnum ne '';
	return $aliases;
}


sub ldap_write_aliases_final ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my $obj = $at->{obj};
	my $old = append_list(nvl($at->{old}), get_attr($obj, 'telnum', orig => 1));
	my $new = append_list(nvl($at->{val}), get_attr($obj, 'telnum'));
	log_debug('write_aliases_final: old="%s" new="%s"', $old, $new);
	return 0 if $old eq $new;
	if ($config{cgp_buggy_ldap}) {
		my $mail = get_attr($obj, 'mail');
		my $res = cli_cmd('SETACCOUNTALIASES %s (%s)', $mail, join_list split_list $new);
		log_debug('set_mail_aliases: code="%s" msg="%s" out="%s"',
					$res->{code}, $res->{msg}, $res->{out});
		return 1 if $res->{code} == 0;
		message_box('error', 'close',
					_T('Cannot change mail aliases for "%s": %s', $mail, $res->{msg}));
		return 0;
	} else {
		my $aliased = get_attr($obj, 'cgpDn');
		log_debug('write_aliases(1): old=(%s) new=(%s)', $old, $new);
		($old, $new) = compare_lists($old, $new);
		log_debug('write_aliases(2): del=(%s) add=(%s)', $old, $new);
		for my $aid (split_list $old) {
			my $dn = make_dn($obj, 'cgp_user_dn', 'uid' => $aid);
			my $res = ldap_delete($srv, $dn);
			log_debug('Removing mail alias "%s" for "%s": %s', $dn, $aliased, $res->error);
		}
		for my $aid (split_list $new) {
			my $dn = make_dn($obj, 'cgp_user_dn', 'uid' => $aid);
			log_debug('Adding mail alias "%s" for "%s": %s', $dn, $aliased, 'unimplemented');
		}
		return $old ne '' || $new ne '';
	}
}


sub ldap_read_mail_groups ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	my $uid = nvl($ldap->get_value('uid'));
	return '' if $uid eq '';
	my $res = ldap_search($srv, "(&(objectClass=CommuniGateGroup)(groupMember=$uid))", ['uid']);
	return join_list map { $_->get_value('uid') } $res->entries;		
}


sub cgp_read_domain_intercept ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	return $domain_intercept if defined $domain_intercept;
	my $res = cli_cmd('GETDOMAINMAILRULES %s', $config{mail_domain});
	if ($res->{code}) {
		log_info('cgp_read_domain_intercept error: %s', $res->{msg});
		return bool2str(0);
	}
	my $rules = str2array($res->{out});
	log_info('cgp_read_domain_intercept: %s', array2str($rules));
	my $ret = -1;
	for my $rule ($rules) {
		if ($$rule[1] =~ /\#Redirect/) {
			if (ref $$rule[2] && ref $$rule[3]) {
				if (nvl($$rule[3][1]) eq $config{cgp_listener}) {
					$ret = 1;
					last;
				}
			}
		}
	}
	log_info('cgp_read_domain_intercept: ret = %d', $ret);
	$domain_intercept = bool2str($ret > 0 ? 1 : 0);
	return $domain_intercept;
}


sub cgp_write_domain_intercept ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my $old = str2bool($at->{old});
	my $new = str2bool($at->{val});
	return 0 if $old == $new;
	my $rule = [
			$new, '"#Redirect"',
			[ '"Human Generated"', '"---"'],
			[ '"Mirror to"', $config{cgp_listener} ]
		];
	my $out = array2str($rule);
	log_info('cgp_write_domain_intercept: rule = %s', $out);
	my $res = cli_cmd('SETDOMAINMAILRULES %s %s', $config{mail_domain}, $out);
	if ($res->{code}) {
		log_info('cgp_write_domain_intercept error: %s', $res->{msg});
		return 0;
	}
	return 1;
}


sub cgp_get_server_intercept ()
{
	return 0 if defined $server_intercept;
	my $res = cli_cmd('GETSERVERINTERCEPT');
	if ($res->{code}) {
		log_info('cgp_get_server_intercept error: %s', $res->{msg});
		return -1;
	}
	$server_intercept = str2dict($res->{out});
	log_debug('cgp_get_server_intercept: %s', dict2str($server_intercept));
	return 0;
}


sub cgp_read_user_intercept ($$$$)
{
	my ($at, $srv, $ldap, $name) = @_;
	my $mail = nvl( $ldap->get_value('mail') );
	return bool2str(0) if $mail eq '' || cgp_get_server_intercept() < 0;
	my $ret = bool2str(defined $server_intercept->{$mail});
	log_debug('cgp_read_user_intercept(%s): %s', $mail, $ret);
	return $ret;
}


sub cgp_write_user_intercept ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my $old = str2bool($at->{old});
	my $new = str2bool($at->{val});
	return 0 if $old == $new;
	return 0 if cgp_get_server_intercept() < 0;
	my $mail = nvl( $ldap->get_value('mail') );
	if ($new) {
		my $opt = {};
		$opt->{SendTo} = $config{cgp_listener};
		for (split_list $config{cgp_intercept_opts}) { $opt->{$_} = 'YES' }
		$server_intercept->{$mail} = $opt;
	} else {
		delete $server_intercept->{$mail};
	}
	my $out = dict2str($server_intercept);
	my $res = cli_cmd('SETSERVERINTERCEPT %s', $out);
	if ($res->{code}) {
		log_info('cgp_write_user_intercept(%s) write error: %s ("%s")',
				$mail, $res->{msg}, $out);
		return 0;
	}
	log_debug('cgp_write_user_intercept(%s) success: %s', $mail, $out);
	return 1;
}


sub cgp_modify_mail_group ($$$$)
{
	my ($srv, $gid, $uid, $action) = @_;
	log_debug('will be %s\'ing mail user "%s" in group "%s"...', $action, $uid, $gid);
	my $retval;
	if ($config{cgp_buggy_ldap}) {
		my $gname = $gid . '@' . $config{mail_domain};
		my $res = cli_cmd('GETGROUP %s', $gname);
		if ($res->{code} == 0) {
			my $dict = str2dict($res->{out});
			log_debug('group "%s" members: %s', $gid, dict2str($dict));
			my $old = nvl($dict->{Members});
			$old = $1 if $old =~ /^\(\s*(.*?)\s*\)$/;
			my $new = $action eq 'add' ? append_list($old, $uid) : remove_list($old, $uid);
			log_debug('group %s members: old=(%s) new=(%s)', $gid, $old, $new);
			return 'SAME' if $old eq $new;
			$dict->{Members} = "($new)";
			my $newparams = dict2str($dict);
			log_debug('newparams: "%s"', $newparams);
			$res = cli_cmd("SETGROUP %s %s", $gname, $newparams);
			if ($res->{code} == 0) {
				$retval = 'OK';
			} else {
				message_box('error', 'close',
						_T('Error modifying mail group "%s": %s', $gid, $res->{msg}));
				$retval = $res->{msg};
			}
		} else {
			message_box('error', 'close',
						_T('Error reading mail group "%s": %s', $gid, $res->{msg}));
			$retval = $res->{msg};
		}
	} else {
		my $res = ldap_search('cgp', "(&(objectClass=CommuniGateGroup)(uid=$gid))",
								['groupMember']);
		my $grp = $res->pop_entry;
		if ($res->code || !$grp) {
			log_info('cannot find mail group "%s" for modification', $gid);
			return $res->error;
		}
		my ($old, $new, @new, $exists);
		$exists = $grp->exists('groupMember') ? 1 : 0;
		$old = $exists ? join_list($grp->get_value('groupMember')) : '';
		$new = $action eq 'add' ? append_list($old, $uid) : remove_list($old, $uid);
		@new = split_list $new;
		if ($old eq $new) {
			log_debug('mail group "%s" wont change with user "%s": (%s) = (%s)',
					$gid, $uid, $old, $new);
			return 'SAME';
		}
		if ($exists) {
			$grp->replace('groupMember' => \@new);
		} else {
			$grp->add('groupMember' => \@new);
		}
		log_debug('modify mail group "%s": user="%s" action="%s" exists="%s" new="%s"',
					$gid, $uid, $action, $exists, join_list @new);
		$res = ldap_update('cgp', $grp);
		if ($res->code) {
			log_info('%s mail user "%s" in group "%s" error: %s',
					$action, $uid, $gid, $res->error);
			$retval = $res->error;
		} else {
			log_debug('success %s\'ing mail user "%s" in group "%s": [%s] -> [%s]...',
						$action, $uid, $gid, $old, $new);
			$retval = 'OK';
		}
	}
	my $sel_mgroup = $mailgroup_obj;
	if (!$sel_mgroup->{changed} && get_attr($sel_mgroup, 'uid') eq $uid) {
		# refresh gui for this mail group (FIXME)
		mailgroup_load();
	}
	return $retval;
}


sub ldap_write_mail_groups_final ($$$$$)
{
	my ($at, $srv, $ldap, $name, $val) = @_;
	my $old = nvl($at->{old});
	my $new = nvl($at->{val});
	return 0 if $old eq $new;
	my $uid = get_attr($at->{obj}, $name);
	log_debug('write_mail_groups(1): old=(%s) new=(%s)', $old, $new);
	($old, $new) = compare_lists($old, $new);
	log_debug('write_mail_groups(2): del=(%s) add=(%s)', $old, $new);
	for my $gid (split_list $old) {
		cgp_modify_mail_group($srv, $gid, $uid, 'remove');
	}
	for my $gid (split_list $new) {
		cgp_modify_mail_group($srv, $gid, $uid, 'add');
	}
	return $old ne '' || $new ne '';
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

	unless ($servers{'cgp'}{disable}) {
		$uid = get_attr($usr, 'uid');
		$msg = ldap_obj_read($usr, 'cgp', "(&(objectClass=CommuniGateAccount)(uid=$uid))");
		log_info('will create mail account for uid "%s"', $uid) if $msg;			
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

	$msg = ldap_obj_write($usr, 'cgp');
	if ($msg) {
		message_box('error', 'close',
				_T('Error updating mail account "%s" (%s): %s',
					get_attr($usr, 'uid'), get_attr($usr, 'cgpDn'), $msg));
	}

	my $home = get_attr($usr, 'homeDirectory');
	if ($config{create_homes} && $home ne '' && !(-d $home)) {
		log_info('creating home directory "%s"', $home);
		$install{src} = $config{skel_dir};
		$install{dst} = $home;
		$install{uidn} = $install{gidn} = 0;
		if ($config{prefer_nss_ids}) {
			my @pwent = getpwnam(get_attr($usr, 'uid'));
			$install{uidn} = $pwent[2] if $pwent[2];
			$install{gidn} = $pwent[3] if $pwent[3];
		}
		$install{uidn} = get_attr($usr, 'uidNumber') unless $install{uidn};
		$install{gidn} = ldap_get_unix_group_ids('uni', get_attr($usr, 'gidNumber'), 'warn') unless $install{gidn};

		my $ret = File::Copy::Recursive::rcopy($install{src}, $install{dst});
		find(sub {
				# FIXME: is behaviour `lchown'-compatible ?
				chown $install{uidn}, $install{gidn}, $File::Find::name;
			}, $install{dst}
		);
	}

	flush_cached_data();
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
		log_debug('ldap_obj_read(%s) [%s]: failed with code %d', $srv, $filter, $res->code);
		return $res->error;
	}
	my $ldap = $obj->{ldap}{$srv} = $res->pop_entry;

	for my $at (@{$obj->{attrs}}) {
		next if $at->{state} ne 'empty';
		my $name = $at->{desc}{ldap}{$srv};
		next unless $name;
		my $val = &{$at->{desc}{ldap_read}} ($at, $srv, $ldap, $name);
		init_attr($obj, $at->{name}, $val);
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

	log_debug('start writing to "%s"...', $srv);

	for my $at (@{$obj->{attrs}}) {
		my $name = $at->{desc}{ldap}{$srv};
		next unless $name;
		$changed |= &{$at->{desc}{ldap_write}} ($at, $srv, $ldap, $name, nvl($at->{val}));
	}

	if ($changed) {
		my $res = ldap_update($srv, $ldap);
		log_debug('writing to "%s" returns code %d', $srv, $res->code);
		# Note: code 82 = `no values to update'
		$msg = $res->error if $res->code && $res->code != 82;
	} else {
		log_debug('no need to write to "%s"', $srv);		
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
	for (ldap_search('uni', '(objectClass=posixGroup)', ['gidNumber'])->entries) {
		my $gidn = $_->get_value('gidNumber');
		$next_gidn = $gidn if $gidn > $next_gidn;
	}
	$next_gidn = $next_gidn > 0 ? $next_gidn + 1 : 1000;
	log_debug('next gidn: %d', $next_gidn);
	return $next_gidn;
}


sub next_cgp_telnum ()
{
	return $next_telnum if defined($next_telnum) && $next_telnum > 0;
	my %taken_telnums;
	for (ldap_search('cgp', "(objectClass=alias)", ['uid'])->entries) {
		my $telnum = $_->get_value('uid');
		next unless $telnum =~ /^\d{3}$/;
		$taken_telnums{$telnum} = $telnum;
	}
	log_debug('next_cgp_telnum: taken=(%s)', join_list keys %taken_telnums);
	for my $i ($config{min_telnum} .. $config{max_telnum}) {
		next if $taken_telnums{$i};
		$next_telnum = $i;
		log_debug('next_cgp_telnum: %d', $next_telnum);
		return $next_telnum;
	}
	log_debug('next_cgp_telnum: none');
	return '';
}


sub make_dn ($$%)
{
	my ($obj, $what, %override) = @_;
	my $dn = $config{$what};
	while ($dn =~ /\$\((\w+)\)/) {
		my $name = $1;
		my $val = nvl($override{$name});
		$val = get_attr($obj, $name) if $val eq '';
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
	cond_set($usr, 'cgpDn', make_dn($usr, 'cgp_user_dn'));

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
	cond_set($usr, 'mail', ifnull($uid, $uid.'@'.$config{mail_domain}));

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

	######## CommuniGate Pro ########
	set_attr($usr, 'cgpObjectClass', append_list(get_attr($usr, 'cgpObjectClass'),
												$config{cgp_user_classes}));

	my $telnum;
	if (has_attr($usr, 'telnum')) {
		$telnum = get_attr($usr, 'telnum');
	} else {
		$telnum = next_cgp_telnum();
	}
	$telnum = substr(sprintf('%03d', $telnum), 0, 3);
	set_attr($usr, 'telnum', $telnum);

	set_attr( $usr, 'domainIntercept', bool2str(get_attr($usr, 'domainIntercept')) );
	set_attr( $usr, 'userIntercept', bool2str(get_attr($usr, 'userIntercept')) );

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


# ======== CGP CLI interface ========


sub cli_connect ()
{
	my $cfg = get_server('cli');
	my $uri = nvl($cfg->{uri});
	$uri =~ /^\s*(?:\w+\:\/\/)?([\w\.\-]+)(?:\s*\:\s*(\d+))[\s\/]*$/
		or log_error('invalid uri for server CLI');
	my ($host, $port) = ($1, $2);
	$host = 'localhost' unless $host;
	$port = 106 unless $port;
	log_debug('cli connection to host (%s), port (%s)', $host, $port);
	($cfg->{user}, $cfg->{pass}) = get_credentials('cli');
	my $cli = Net::Telnet->new(	-timeout => $config{cli_timeout}, -errmode => 'return',
								-prompt => '/\d{3} .*$/');
	$cfg->{cli} = $cli;
	$cli->dump_log(*STDERR) if $cfg->{debug};	
	$cli->open(-host => $host, -port => $port)
		or log_error('cannot bind to CLI: network error');
	log_debug('cli connect as user (%s), pass (%s)', $cfg->{user}, $cfg->{pass});
	my $res = cli_cmd('');
	if ($res->{code} == 0) {
		log_error('unexpected CLI handshake: "%s" "%s"', $res->{msg}, $res->{out})
			unless $res->{msg} =~ /(\<.*\@*\>)/;
		my $serv = $1;
		my $md5 = Digest::MD5->new;
		$md5->add($serv . $cfg->{pass});
		my $digest = $md5->hexdigest;
		$res = cli_cmd('APOP %s %s', $cfg->{user}, $digest);
	}
	if ($res->{code}) {
		log_error('cannot connect to CLI: %s', $res->{msg}) if $res->{code};
		return -1;
	}
	log_debug('successfully connected to CLI');
	$cfg->{connected} = 1;
	$cfg->{timer_id} = Glib::Timeout->add($config{cli_idle_interval} * 1000, \&cli_idle);
	return 0;
}


sub cli_disconnect ()
{
	my $cfg = get_server('cli');
	cli_cmd('QUIT');
	Glib::Source->remove($cfg->{timer_id}) if defined $cfg->{timer_id};
	undef $cfg->{timer_id};
}


sub cli_idle ()
{
	cli_cmd('NOOP') if get_server('cli')->{connected};
	return 1;
}


sub cli_cmd ($@)
{
	my $fmt = shift;
	my $cmd = sprintf(nvl($fmt), @_);
	my $cfg = get_server('cli');
	my $cli = $cfg->{cli};
	my (@dbg, $out, $pre, $match, $code, $msg, $data_timeout);
	return { code => -1, msg => 'disabled', out => '' } if $cfg->{disable};
	return { code => -1, msg => 'eof', out => '' } if $cli->eof;
	if ($cmd ne '') { eval { $cli->print($cmd) } }
	($dbg[0] = $cmd) =~ s/[\r\n\s]+/ /g;
	($pre, $match) = eval {
		$cli->waitfor(-match => '/\d{3} /', -timeout => $config{cli_timeout})
	};
	unless (defined $match) {
		log_info('cli_cmd: no match for cmd="%s"', $dbg[0]);
		return { code => -1, msg => 'nomatch', out => '' };
	}
	($pre = nvl($pre)) =~ s/[\r\n\s]+/ /g;
	$code = int($match);
	$msg = nvl( eval { $cli->getline(-timeout => 1) });
	$data_timeout = ($msg =~ /data follow/) ? 1 : 0;
	$out = '';
	for (1 .. 3) {
		$out .= nvl( join '', eval {
						$cli->getlines(-all => 0, -timeout => $data_timeout)
				} );
		my $count = 0;
		for (split //, $out) {
			$count++ if $_ eq '(' || $_ eq '{';
			$count-- if $_ eq ')' || $_ eq '}';
		}
		last if $count == 0;
		log_debug('need more iterations to gather tail');
	}
	$out =~ s/\s*[\r\n]+\s*/\n/g;
	($dbg[1] = $out) =~ s/\n/|/g;
	log_debug('cli_cmd: cmd=<%s> code=%d msg="%s" out=<%s>', $dbg[0], $code, $msg, $dbg[1]);
	log_error('cli_cmd: unexpected input pre=<%s>', $pre) if $pre ne '';
	$code = 0 if $code == 200;
	return { code => $code, msg => $msg, out => $out };
}


sub __dict2str ($);
sub __str2dict ($);


sub str2dict ($)
{
	my $t = [ split /\n/, $_[0] ];
	my $d = __str2dict($t);
	log_debug('str2dict: (%s)', join_list map "$_ = $d->{$_}", keys %$d);
	return $d;
}


sub __str2dict ($)
{
	my $t = $_[0];
	my $d = {};
	while (defined($_ = shift @$t)) {
		next if /^$/;
		next if /^\{$/;
		last if /^\}\;?$/;
		last if /^\{\s*\}$/;  
		if (/^\{\s*((?:\s*\S+\s+=\s+\S+\s*\;\s*)+)}\s*$/) {
			for (split /\s*\;\s*/, $1) {
				/(\S+)\s+=\s+(\S+)/ and $d->{$1} = $2;
			}
			next;
		}
		if (/^(\S+)\s+=\s+\{$/) {
			$d->{$1} = __str2dict($t);
			next;
		}
		if (/^(\S+)\s+=\s+\{\s+(\S+)\s+=\s+(\S+?)\;\s*\}\s*\;$/) {
			$d->{$1} = { $2 => $3 };
			next;
		}
		if (/^(\w+)\s*=\s*(.*?)\s*\;\s*(\}?)$/) {
			$d->{$1} = $2;
			last if nvl($3) eq '}';
			next;
		}
		log_error('str2dict: strange line: "%s"', $_);
	}
	return $d;
}


sub dict2str ($)
{
	my $s = __dict2str($_[0]);
	log_debug('dict2str: %s', $s);
	return $s;
}


sub __dict2str ($)
{
	my $d = shift;
	my $s = '{ ';
	for my $k (sort keys %$d) {
		my $v = $d->{$k};
		$s .= $k . ' = ';
		if (ref $v) {
			$s .= __dict2str($v);
		} else {
			(my $x = $v) =~ s/[0-9a-xA-Z_\@]//g;
			my $q = $x eq '' ? '' : '"';
			if ($v =~ /^\".*?\"$/ || $v =~ /^\(.*?\)$/) {
				$q = '';
			} else {
				$v =~ s/\"/\\"/g;
			}
			$s .= $q.$v.$q;
		}
		$s .= '; ';
	}
	return $s . '}';
}


sub str2array ($)
{
	my @s = split /\n/, $_[0];
	my @a;
	my $brcount = 0;
	for my $s (@s) {
		next if $s =~ /^$/;
		if ($s =~ /^\(+$/) {
			$brcount += length($s);
			next;
		}
		if ($s =~ /^\)+$/) {
			$brcount -= length($s);
			last if $brcount <= 0;
			next;
		}
		if ($s =~ /^\(\(\s*(.*?)\s*\)\)\s*,?$/) {
			push @a, [ split /\s*,\s*/, $1 ];
			next;
		}
		if ($s =~ /^(\d+|"\S+?"),?$/) {
			push @a, $1;
			next;
		}
		log_error('str2array: strange line: "%s"', $s);
	}
	log_debug('str2array: (%s)', join_list @a);
	return \@a;
}


sub array2str ($)
{
	my @a = @{$_[0]};
	my $s = '( ( ';
	for my $i (0 .. $#a) {
		$s .= ref $a[$i] ? '(('.join(', ',@{$a[$i]}).'))' : $a[$i];
		$s .= $i < $#a ? ', ' : '';
	}
	$s .= ' ) )';
	log_debug('array2str: %s', $s);
	return $s;
}


# ======== connections ========


sub flush_cached_data ()
{
	$next_uidn = $next_gidn = $next_telnum = undef;
	$domain_intercept = $server_intercept = undef;
}


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
	return $ent->update(get_server($srv,1)->{ldap});
}


sub ldap_delete ($$)
{
	my ($srv, $ent) = @_;
	return get_server($srv,1)->{ldap}->delete($ent);
}


sub get_credentials ($)
{
	my $srv = shift;
	my $cfg = get_server($srv);
	my $user = nvl($cfg->{user});
	my $pass = $user eq '' ? '' : nvl($cfg->{pass});
	if ($pass eq '') {
		my $secret = nvl($cfg->{passfile});
		$secret = nvl($config{passfile}) if $secret eq '';
		open (SECRET, $secret)
			or log_error('cannot open passfile "%s"', $secret);
		while (<SECRET>) {
			next if /^\s*$/ || /^\s*#$/;
			/^\s*([^\s'"]+|'[^']*'|"[^"]*")\s+([^\s'"]+|'[^']*'|"[^"]*")\s+([^\s'"]+|'[^']*'|"[^"]*")\s*$/
				or log_error('syntax error in line %d of "%s"', $., $secret);
			my ($iserv, $iuser, $ipass) = ($1, $2, $3);
			$iserv = nvl($1) if $iserv =~ /^'(.*?)'$/ || $iserv =~ /^"(.*?)"$/;
			$iuser = nvl($1) if $iuser =~ /^'(.*?)'$/ || $iuser =~ /^"(.*?)"$/;
			$ipass = nvl($1) if $ipass =~ /^'(.*?)'$/ || $ipass =~ /^"(.*?)"$/;
			#log_debug('secret: srv="%s" user="%s" pass="%s"', $iserv, $iuser, $ipass);
			next if $iserv ne $srv;
			if ( ($user ne '' && ($iuser eq $user || $iuser eq '*'))
					|| ($user eq '' && $iuser ne '*') ) {
				$user = $iuser if $user eq '';
				$pass = $ipass;
				last;
			}
		}
		close SECRET;
		log_error('cannot find credentials for server "%s"', $srv)
			if $user eq '' || $pass eq '';
	}
	return ($user, $pass);
}


sub ldap_connect_to ($)
{
	my $srv = shift;
	my $cfg = $servers{$srv};
	$cfg->{name} = $srv;
	$cfg->{connected} = 0;
	if ($srv eq 'cli') {
		return cli_connect();
	}
	if ($cfg->{disable}) {
		$cfg->{ldap} = Net::LDAP->new;
		return 0;
	}
	my $uri = nvl($cfg->{uri});
	log_error('invalid uri for server "%s"', $srv) if $uri eq '';
	($cfg->{user}, $cfg->{pass}) = get_credentials($srv);
	$cfg->{ldap} = Net::LDAP->new($uri, debug => $cfg->{debug});
	log_debug('connecting to server "%s"...', $srv);			
	my $res = $cfg->{ldap}->bind($cfg->{user}, password => $cfg->{pass});
	if ($res->code) {
		log_error('cannot bind to server "%s": %s', $srv, $res->error);
		return -1;
	}
	$cfg->{connected} = 1;
	log_debug('successfully connected to server "%s"', $srv);			
	return 0;	
}


my $connect_done :shared;

sub background_dialog ($)
{
	my $srv = shift;
	my $info = Gtk2::MessageDialog->new(
				undef, 'modal', 'info', 'close',
				_T('Connecting to "%s" ...', $srv)
			);
	my $timer_id = Glib::Timeout->add(100, sub {
		if ($connect_done) {
			$info->response(1);
			return 0;
		}
		return 1;
	});
	$info->run;
	Glib::Source->remove($timer_id);
	$info->hide;
	exit() unless $connect_done;
}


sub ldap_connect_all ()
{
	$connect_done = 0;
	#my $thr = threads->create(sub { background_dialog('server') });
	for my $srv (keys %servers) {
		log_info('connecting to "%s"', $srv);
		ldap_connect_to($srv);
	}
	$connect_done = 1;
	#$thr->join;
}


sub ldap_disconnect_all ()
{
	for my $cfg (values %servers) {
		next if $cfg->{disable};
		next unless $cfg->{connected};
		if ($cfg->{name} eq 'cli') {
			cli_disconnect();
		} else {
			$cfg->{ldap}->disconnect;
		}
		$cfg->{connected} = 0;
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
	my $model = $user_list->get_model;
	my $node = $model->get_iter($path);
	my $usr = $user_obj;
	return unless $usr->{changed};

	my $pass = get_attr($usr, 'password');
	if ($pass ne get_attr($usr, 'password2')) {
		message_box('error', 'close', _T('Passwords dont match'));
		focus_attr($usr, 'password');
		return;
	}
	unless (isascii $pass) {
		my $resp = message_box('question', 'yes-no',
							_T('Password contains non-basic characters. Are you sure ?'));
		if ($resp ne 'yes') {
			focus_attr($usr, 'password');
			return;
		}
	}
	unless (isascii(get_attr($usr, 'aliases'))) {
		my $resp = message_box('warning', 'close',
								_T('Mail aliases should not contain non-basic characters'));
		focus_attr($usr, 'aliases');
		return;
	}

	my $uid = get_attr($usr, 'uid');
	if (is_new_user($node) && is_reserved_name($uid)) {
		message_box('warning', 'close', _T('This object name is reserved'));
		focus_attr($usr, 'uid');
		return;		
	}

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
	focus_attr($usr, $gui_attrs{user}[0][1]);
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
		if (is_reserved_name($uid)) {
			message_box('warning', 'close', _T('Cannot delete reserved object'));
			return;
		}

		my $resp = message_box('question', 'yes-no', _T('Delete user "%s" ?', $uid));
		return if $resp ne 'yes';

		rework_user($usr);	# produce dn and ntDn
		my $dn = get_attr($usr, 'dn');

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
			my $ntDn = get_attr($usr, 'ntDn');
			$res = ldap_delete('ads', $ntDn);
			if ($res->code) {
				message_box('error', 'close',
					_T('Error deleting Windows-user "%s" (%s): %s', $uid, $ntDn, $res->error));
			}
		}

		unless ($servers{'cgp'}{disable}) {
			my $cgpDn = get_attr($usr, 'cgpDn');
			$res = ldap_delete('cgp', $cgpDn);
			if ($res->code) {
				message_box('error', 'close',
					_T('Error deleting mail account "%s" (%s): %s', $uid, $cgpDn, $res->error));
			}
			my $mgroups = get_attr($usr, 'mailgroups', orig => 1);
			my $uid = get_attr($usr, 'uid');
			for my $gid (split_list $mgroups) {
				cgp_modify_mail_group('cgp', $gid, $uid, 'remove');
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

	my $btn_close;
	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) }, \$btn_close ],
	);

	$vbox->pack_end($buttons, 0, 0, 2);
	$wnd->set_default_size(150, 200);
	$btn_close->can_default(1);
	$wnd->set_default($btn_close);
	show_popup($wnd, $popup_btn);
}


sub yesno_selected ($$$$)
{
	my ($at, $list, $wnd, $btn) = @_;
	my ($path, $column) = $list->get_cursor;
	my $model = $list->get_model;
	set_attr($at->{obj}, $at->{name}, $model->get($model->get_iter($path), 0));
	update_obj_gui($at->{obj});
	set_user_changed(obj_changed($at->{obj}));
	$btn->set_sensitive(1);
	$wnd->hide;
}


sub create_yesno_chooser ($)
{
	my $at = shift;
	my $btn = $at->{popup};
	my $model = Gtk2::TreeStore->new(qw(Glib::String));
	my @node;
	$node[0] = $model->append(undef);
	$model->set($node[0], 0, 'No');
	$node[1] = $model->append(undef);
	$model->set($node[1], 0, 'Yes');
	my $list = Gtk2::TreeView->new;
	$list->set_model($model);
	$list->insert_column_with_attributes(0, '', Gtk2::CellRendererText->new, text => 0);
	$list->set_headers_visible(0);
	$list->set_cursor($model->get_path($node[str2bool($at->{entry}->get_text)]));			
	my $wnd = Gtk2::Window->new("toplevel");
	$wnd->add($list);
	$wnd->set_title("Yes/No");
	$list->signal_connect(cursor_changed => sub { yesno_selected($at, $list, $wnd, $btn) });
	show_popup($wnd, $btn);
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

	my $btn_close;
	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) }, \$btn_close ],
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
	$btn_close->can_default(1);
	$wnd->set_default($btn_close);
	show_popup($wnd, $popup_btn);
}


sub user_mail_group_toggled ($$)
{
	my ($btn, $at) = @_;
	return user_group_toggled($btn, $at);
}


sub create_user_mail_groups_editor ($)
{
	my $at = shift;
	my $popup_btn = $at->{popup};

	my $res = ldap_search('cgp', "(objectClass=CommuniGateGroup)", ['uid']);
	my @groups = $res->entries;
	return if $#groups < 0;

	my $wnd = Gtk2::Window->new("toplevel");
	$wnd->set_title("Mail Groups...");
	my $vbox = Gtk2::VBox->new(0, 0);
	$wnd->add($vbox);
	my $scroll = Gtk2::ScrolledWindow->new;
	$vbox->pack_start($scroll, 1, 1, 1);
	$scroll->set_policy("automatic", "automatic");
	my $list = new Gtk2::VBox(0, 0);
	$scroll->add_with_viewport($list);

	my %groups0;
	map { $groups0{$_} = 1 } split_list $at->{entry}->get_text;	

	for my $gid (sort {$a cmp $b} map { $_->get_value('uid') } @groups) {
		my $btn = create_button($gid, undef, toggle => 1, rightpic => 1);
		$btn->signal_connect(toggled => sub { user_mail_group_toggled($btn, $at); });
		my $active = defined $groups0{$gid};
		set_button_image($btn, $toggle_icon[$active ? 1:0]);
		$btn->set_active($active);
		$btn->set_relief('none');
		my $frame = Gtk2::Frame->new;
		$frame->add($btn);
		$list->pack_start($frame, 0, 0, 0);
		$list->pack_start(Gtk2::HSeparator->new, 0, 0, 0);
	}

	my $btn_close;
	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) }, \$btn_close ],
	);

	$vbox->pack_end($buttons, 0, 0, 2);
	$wnd->set_default_size(150, 200);
	$btn_close->can_default(1);
	$wnd->set_default($btn_close);
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
	my $tab_no = 0;
	$user_attr_tabs = $tabs;
	$tabs->set_tab_pos("top");
	$frame = Gtk2::Frame->new(_T('Attributes'));
	$frame->add($tabs);
	$user_attr_frame = $frame;
	$vbox->pack_start($frame, 1, 1, 0);

	for (@{$gui_attrs{user}})
	{
		my ($tab_name, @tab_attrs) = @$_;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, _T($tab_name));
		$scroll->set_policy('automatic', 'automatic');
		$scroll->set_border_width(0);

		my $abox = Gtk2::Table->new($#tab_attrs + 1, 4);
		$scroll->add_with_viewport($abox);

		for my $r (0 .. $#tab_attrs) {
			next unless attribute_enabled('user', $tab_attrs[$r]);
			my $at = setup_attr($usr, $tab_attrs[$r], 1);
			$at->{tab_book} = $tabs;
			$at->{tab_page} = $tab_no;
			$abox->attach($at->{bulb}, 0, 1, $r, $r+1, [], [], 1, 1) if $at->{bulb};
			$abox->attach($at->{label}, 1, 2, $r, $r+1, [], [], 1, 1);
			my $right = 4;
			if ($at->{popup}) {
				$abox->attach($at->{popup}, 3, 4, $r, $r+1, [], [], 1, 1);
				$right = 3;
			}
			$abox->attach($at->{entry}, 2, $right, $r, $r+1, [ 'fill', 'expand' ], [], 1, 1);
			$at->{entry}->signal_connect(key_release_event => sub { user_entry_edited($at) })
		}

		$tab_no++;
	}

	my $buttons = create_button_bar(
		[],
		[ _T('Save'), "apply.png", \&user_save, \$btn_usr_apply ],
		[ _T('Revert'), "revert.png", \&user_revert,\$btn_usr_revert ],
	);
	$vbox->pack_end($buttons, 0, 0, 2);

	$btn_usr_apply->can_default(1);

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

	if (is_new_group($node) && is_reserved_name($gid)) {
		message_box('warning', 'close', _T('This object name is reserved'));
		focus_attr($grp, 'cn');
		return;		
	}

	$model->set($node, 0, $gid);
	$grp->{changed} = obj_changed($grp);
	my $msg = ldap_obj_write($grp, 'uni');
	if ($msg) {
		message_box('error', 'close', _T('Error saving group "%s": %s', $gid, $msg));
		return undef;
	}

	flush_cached_data();

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

	focus_attr($grp, $gui_attrs{group}[0][1]);
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
		if (is_reserved_name($gid)) {
			message_box('warning', 'close', _T('Cannot delete reserved object'));
			return;
		}

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
	update_obj_gui($grp);
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
	my @users = map { $_->get_value('uid') } $res->entries;
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

	for (@users) { $users{$_} = 1 }
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

	my $btn_close;
	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) }, \$btn_close ],
	);

	$vbox->pack_end($buttons, 0, 0, 2);
	$wnd->set_default_size(150, 200);
	$btn_close->can_default(1);
	$wnd->set_default($btn_close);
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
	my $tab_no = 0;
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
			next unless attribute_enabled('group', $tab_attrs[$r]);
			my $at = setup_attr($grp, $tab_attrs[$r], 1);
			$at->{tab_book} = $tabs;
			$at->{tab_page} = $tab_no;
			$abox->attach($at->{bulb}, 0, 1, $r, $r+1, [], [], 1, 1) if $at->{bulb};
			$abox->attach($at->{label}, 1, 2, $r, $r+1, [], [], 1, 1);
			my $right = 4;
			if ($at->{popup}) {
				$abox->attach($at->{popup}, 3, 4, $r, $r+1, [], [], 1, 1);
				$right = 3;
			}
			$abox->attach($at->{entry}, 2, $right, $r, $r+1, [ 'fill', 'expand' ], [], 1, 1);
			$at->{entry}->signal_connect(key_release_event => sub { group_entry_edited($at) });
		}

		$tab_no++;
	}

	my $buttons = create_button_bar(
		[],
		[ _T('Save'), "apply.png", \&group_save, \$btn_grp_apply ],
		[ _T('Revert'), "revert.png", \&group_revert,\$btn_grp_revert ],
	);
	$vbox->pack_end($buttons, 0, 0, 2);

	$btn_grp_apply->can_default(1);

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


# ======== mail group gui ========


sub is_new_mailgroup ($)
{
	my $node = shift;
	my $model = $mailgroup_list->get_model;
	return 0 unless defined $node;
	my $gid = $model->get($node, 0);
	return ($gid eq '-' ? 1 : 0);
}


sub mailgroup_save ()
{
	my ($path, $column) = $mailgroup_list->get_cursor;
	return unless defined $path;
	my $mgrp = $mailgroup_obj;
	return unless $mgrp->{changed};

	my $model = $mailgroup_list->get_model;
	my $node = $model->get_iter($path);
	my $gid = get_attr($mgrp, 'uid');
	$model->set($node, 0, $gid);

	if (is_new_mailgroup($node) && is_reserved_name($gid)) {
		message_box('warning', 'close', _T('This object name is reserved'));
		focus_attr($mgrp, 'uid');
		return;		
	}

	rework_mailgroup($mgrp);
	$mgrp->{changed} = obj_changed($mgrp);

	my $gname = $gid . '@' . $config{mail_domain};
	my $dict = str2dict(get_attr($mgrp, 'params'));
	$dict->{RealName} = get_attr($mgrp, 'cn');
	$dict->{Members} = '(' . (join_list split_list get_attr($mgrp, 'groupMember')) . ')';

	my $cmd = cli_cmd("GETGROUP $gname")->{code} ? 'CREATEGROUP' : 'SETGROUP';
	$cmd = "$cmd $gname ".dict2str($dict);
	log_debug('mailgroup_save: %s', $cmd);
	my $res = cli_cmd($cmd);
	if ($res->{code}) {
		message_box('error', 'close',
					_T('Error saving mail group "%s": %s', $gid, $res->{msg}));
		return undef;
	}

	flush_cached_data();
	mailgroup_load();
	set_mailgroup_changed(0);
	$btn_mgrp_add->set_sensitive(1);
}


sub mailgroup_revert ()
{
	my $resp = message_box('question', 'yes-no', _T('Really revert changes ?'));
	return if $resp ne 'yes';
	set_mailgroup_changed(0);
	$btn_mgrp_add->set_sensitive(1);
	mailgroup_load();
}


sub mailgroup_add ()
{
	mailgroup_unselect();
	my $model = $mailgroup_list->get_model;
	my $mgrp = $mailgroup_obj;

	my $node = $model->get_iter_first;
	while (defined $node) {
		return if is_new_mailgroup($node);
		$node = $model->iter_next($node);
	}

	$node = $model->append(undef);
	$model->set($node, 0, '-');

	my $path = $model->get_path($node);
	$mailgroup_list->set_cursor($path);

	focus_attr($mgrp, $gui_attrs{mailgroup}[0][1]);
	set_mailgroup_changed(0);
	$btn_mgrp_add->set_sensitive(0);

	mailgroup_load();
}


sub mailgroup_delete ()
{
	my ($path, $column) = $mailgroup_list->get_cursor;
	return unless defined $path;
	my $model = $mailgroup_list->get_model;
	my $mgrp = $mailgroup_obj;

	my $node = $model->get_iter($path);
	my $gid = $model->get($node, 0);

	if (is_new_mailgroup($node)) {
		my $resp = message_box('question', 'yes-no', _T('Cancel new mail group ?', $gid));
		return if $resp ne 'yes';		
	} else {
		if (is_reserved_name($gid)) {
			message_box('warning', 'close', _T('Cannot delete reserved object'));
			return;
		}

		my $resp = message_box('question', 'yes-no', _T('Delete mail group "%s" ?', $gid));
		return if $resp ne 'yes';

		my $res = cli_cmd('DELETEGROUP %s@%s', $gid, $config{mail_domain});
		if ($res->{code}) {
			message_box('error', 'close',
					_T('Error deleting mail group "%s": %s', $gid, $res->error));
			return;
		}
	}

	$model->remove($node);
	set_group_changed(0);
	$btn_mgrp_add->set_sensitive(1);

	if ($path->prev || $path->next) {
		$mailgroup_list->set_cursor($path);
		mailgroup_load();
	} else {
		mailgroup_unselect();
	}
}


sub mailgroups_refresh ()
{
	mailgroup_unselect();

	my $model = $mailgroup_list->get_model;
	$model->clear;

	my $res = ldap_search('cgp', '(objectClass=CommuniGateGroup)', ['uid']);
	my @mailgroups = sort { $a cmp $b } map { $_->get_value('uid') } $res->entries;

	for my $gid (@mailgroups) {
		my $node = $model->append(undef);
		$model->set($node, 0, nvl($gid));
	}

	$btn_mgrp_add->set_sensitive(1) if defined $btn_mgrp_add;
}


sub mailgroup_change ()
{
	my ($path, $column) = $mailgroup_list->get_cursor;
	my $model = $mailgroup_list->get_model;
	if (defined $path) {
		my $node = $model->get_iter($path);
		$model->remove($node) if is_new_mailgroup($node);
		$btn_mgrp_add->set_sensitive(1);
	}
}


sub mailgroup_unselect ()
{
	# exit if interface is not built complete
	return unless defined $mailgroup_name;
	my $mgrp = $mailgroup_obj;
	clear_obj($mgrp);
	$mailgroup_name->set_text('');
	for ($btn_mgrp_apply, $btn_mgrp_revert, $btn_mgrp_delete) { $_->set_sensitive(0) }
	$mailgroup_attr_frame->set_sensitive(0);
	return 0;
}


sub mailgroup_load ()
{
	my ($path, $column) = $mailgroup_list->get_cursor;
	return unless defined $path;

	my $model = $mailgroup_list->get_model;
	my $node = $model->get_iter($path);
	my $gid = $model->get($node, 0);
	return unless defined $gid;

	my $mgrp = $mailgroup_obj;
	clear_obj($mgrp);

	unless (is_new_mailgroup($node)) {
		my $res = cli_cmd('GETGROUP %s@%s', $gid, $config{mail_domain});
		if ($res->{code} == 0) {
			my $dict = str2dict($res->{out});
			my $val = nvl($dict->{Members});
			$val = $1 if $val =~ /^\(\s*(.*?)\s*\)$/;
			init_attr($mgrp, 'uid', $gid);
			my $cn = $dict->{RealName};
			$cn = $1 if $cn =~ /^\"(.*?)\"$/;
			init_attr($mgrp, 'cn', $cn);
			init_attr($mgrp, 'groupMember', join_list split_list $val);
			delete $dict->{Members};
			delete $dict->{RealName};
			init_attr($mgrp, 'params', dict2str($dict));
		} else {
			message_box('error', 'close',
						_T('Cannot display mail group "%s"', $gid).": ".$res->{msg});
		}
	}

	update_obj_gui($mgrp);
	$mailgroup_name->set_text($gid);
	$btn_mgrp_delete->set_sensitive(1);
	$mailgroup_attr_frame->set_sensitive(1);
}


sub rework_mailgroup ($)
{
	my $mgrp = shift;

	set_attr($mgrp, 'uid', string2id(get_attr($mgrp, 'uid')));
	set_attr($mgrp, 'dn', make_dn($mgrp, 'cgp_user_dn'));
	cond_set($mgrp, 'cn', get_attr($mgrp, 'uid'));

	###### constant fields ########
	for my $at (@{$mgrp->{attrs}}) {
		my $desc = $at->{desc};
		cond_set($mgrp, $at->{name}, $desc->{default})
			if defined $desc->{default};
	}
}


sub mailgroup_entry_edited ($)
{
	my $at = shift;
	my $mgrp = $at->{obj};

	my $val = nvl($at->{entry}->get_text);
	return if $val eq $at->{val};
	set_attr($mgrp, $at->{name}, $val);

	rework_mailgroup($mgrp);
	update_obj_gui($mgrp);
	$mailgroup_name->set_text(get_attr($mgrp, 'uid'));
	set_mailgroup_changed(obj_changed($mgrp));
}


sub set_mailgroup_changed ($)
{
	my $chg = shift;
	my $mgrp = $mailgroup_obj;
	$mgrp->{changed} = $chg;
	for ($btn_mgrp_apply, $btn_mgrp_revert)
		{ $_->set_sensitive($chg) }
	for ($btn_mgrp_refresh, $btn_mgrp_add, $btn_mgrp_delete, $mailgroup_list)
		{ $_->set_sensitive(!$chg) }
}


sub mailgroup_user_toggled ($$)
{
	my ($btn, $at) = @_;
	my $uid = get_button_label($btn);
	my $active = $btn->get_active;
	set_button_image($btn, $toggle_icon[$active ? 1:0]);
	my $mgrp = $at->{obj};
	my $val = nvl($at->{entry}->get_text);
	$val = $active ? append_list($val,$uid) : remove_list($val,$uid);
	set_attr($mgrp, $at->{name}, $val);
	update_obj_gui($mgrp);
	set_mailgroup_changed(obj_changed($mgrp));
}


sub create_mailgroup_users_editor ($)
{
	my $at = shift;
	my $popup_btn = $at->{popup};

	my $res = ldap_search('cgp', "(objectClass=CommuniGateAccount)", [ 'uid' ]);
	my @users = map { $_->get_value('uid') } $res->entries;
	return if $#users < 0;

	my $wnd = Gtk2::Window->new("toplevel");
	$wnd->set_title("Users in Mail Group");
	my $vbox = Gtk2::VBox->new(0, 0);
	$wnd->add($vbox);
	my $scroll = Gtk2::ScrolledWindow->new;
	$vbox->pack_start($scroll, 1, 1, 1);
	$scroll->set_policy("automatic", "automatic");
	my $list = new Gtk2::VBox(0, 0);
	$scroll->add_with_viewport($list);

	my (%users0, %users);
	for (split_list $at->{entry}->get_text) { $users0{$_} = 1 }

	for (@users) { $users{$_} = 1 }
	for (keys %users0) { $users{$_} = 1 }

	for my $uid (sort keys %users) {
		my $btn = create_button($uid, undef, toggle => 1, rightpic => 1);
		$btn->signal_connect(toggled => sub { mailgroup_user_toggled($btn, $at); });
		my $active = defined $users0{$uid};
		set_button_image($btn, $toggle_icon[$active ? 1:0]);
		$btn->set_active($active);
		$btn->set_relief('none');
		my $frame = Gtk2::Frame->new;
		$frame->add($btn);
		$list->pack_start($frame, 0, 0, 0);
		$list->pack_start(Gtk2::HSeparator->new, 0, 0, 0);
	}

	my $btn_close;
	my $buttons = create_button_bar(
		[],
		[ _T('Close'), "apply.png", sub { destroy_popup($wnd, $popup_btn) }, \$btn_close ],
	);

	$vbox->pack_end($buttons, 0, 0, 2);
	$wnd->set_default_size(150, 200);
	$btn_close->can_default(1);
	$wnd->set_default($btn_close);
	show_popup($wnd, $popup_btn);
}


sub create_mailgroup_desc ()
{
	my $vbox = Gtk2::VBox->new(0, 0);
	my $frame;

	my $mgrp = $mailgroup_obj = create_obj('mailgroup');

	$mailgroup_name = Gtk2::Label->new;
	my $bname = Gtk2::Button->new;
	$bname->add($mailgroup_name);
	$bname->set_sensitive(0);
	$vbox->pack_start($bname, 0, 1, 4);

	my $tabs = Gtk2::Notebook->new;
	my $tab_no = 0;
	$tabs->set_tab_pos("top");
	$frame = Gtk2::Frame->new(_T('Attributes'));
	$frame->add($tabs);
	$mailgroup_attr_frame = $frame;
	$vbox->pack_start($frame, 1, 1, 0);

	for (@{$gui_attrs{mailgroup}}) {
		my ($tab_name, @tab_attrs) = @$_;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, _T($tab_name));
		$scroll->set_policy('automatic', 'automatic');
		$scroll->set_border_width(0);

		my $abox = Gtk2::Table->new($#tab_attrs + 1, 3);
		$scroll->add_with_viewport($abox);

		for my $r (0 .. $#tab_attrs) {
			next unless attribute_enabled('mailgroup', $tab_attrs[$r]);
			my $at = setup_attr($mgrp, $tab_attrs[$r], 1);
			$at->{tab_book} = $tabs;
			$at->{tab_page} = $tab_no;
			$abox->attach($at->{bulb}, 0, 1, $r, $r+1, [], [], 1, 1) if $at->{bulb};
			$abox->attach($at->{label}, 1, 2, $r, $r+1, [], [], 1, 1);
			my $right = 4;
			if ($at->{popup}) {
				$abox->attach($at->{popup}, 3, 4, $r, $r+1, [], [], 1, 1);
				$right = 3;
			}
			$abox->attach($at->{entry}, 2, $right, $r, $r+1, [ 'fill', 'expand' ], [], 1, 1);
			$at->{entry}->signal_connect(key_release_event => sub { mailgroup_entry_edited($at) });
		}

		$tab_no++;
	}

	my $buttons = create_button_bar(
		[],
		[ _T('Save'), "apply.png", \&mailgroup_save, \$btn_mgrp_apply ],
		[ _T('Revert'), "revert.png", \&mailgroup_revert,\$btn_mgrp_revert ],
	);
	$vbox->pack_end($buttons, 0, 0, 2);

	$btn_mgrp_apply->can_default(1);

	return $vbox;
}


sub create_mailgroup_list ()
{
	$mailgroup_list = Gtk2::TreeView->new;
	$mailgroup_list->set_rules_hint(1);
	$mailgroup_list->get_selection->set_mode('single');
	$mailgroup_list->set_size_request(300, 300);

	my $model = Gtk2::TreeStore->new('Glib::String');
	$mailgroup_list->set_model($model);

	my $off = $mailgroup_list->insert_column_with_attributes(
				-1, _T('Maill group name'), Gtk2::CellRendererText->new, text => 0);
	$mailgroup_list->get_column($off - 1)->set_clickable(1);

	my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
	$scroll->set_policy('automatic', 'automatic');  
	$scroll->add($mailgroup_list);

	my $frame = Gtk2::Frame->new;
	$frame->set_shadow_type('in');
	$frame->add($scroll);

	$mailgroup_list->signal_connect(cursor_changed => \&mailgroup_load);
	$mailgroup_list->signal_connect(move_cursor => \&mailgroup_change);

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
	mailgroup_unselect();
	ldap_disconnect_all();
	Gtk2->main_quit;
	exit;
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
	setup_all_attrs();

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

	$vbox = Gtk2::VBox->new;
	$tabs->append_page($vbox, _T(' Mail groups '));
	$hpane = Gtk2::HPaned->new;
	$hpane->add1(create_mailgroup_list());
	$hpane->add2(create_mailgroup_desc());
	$buttons = create_button_bar (
		[ undef, "userman_32x32.png", 'pic' ],
		[ _T('Create'), "add.png", \&mailgroup_add, \$btn_mgrp_add ],
		[ _T('Delete'), "delete.png", \&mailgroup_delete, \$btn_mgrp_delete ],
		[ _T('Refresh'), "refresh.png", \&mailgroups_refresh, \$btn_mgrp_refresh ],
		[],
		[ _T('Exit'), "exit.png", \&gui_exit ],
	);
	$vbox->pack_start($hpane, 1, 1, 1);
	$vbox->pack_end($buttons, 0, 0, 1);

	my $ltitle = Gtk2::Label->new;
	$ltitle->set_markup(sprintf '<b>%s</b>', _T('Manage Users'));
	my $ftitle = Gtk2::Frame->new;
	$ftitle->set_shadow_type('out');
	$ftitle->add($ltitle);
	$vbox = Gtk2::VBox->new;
	$vbox->pack_start($ftitle, 0, 0, 1);
	$vbox->pack_end($tabs, 1, 1, 1);
	$main_wnd->add($vbox);

	user_unselect();
	group_unselect();
	mailgroup_unselect();

	$main_wnd->signal_connect(delete_event	=> \&gui_exit);
	$main_wnd->signal_connect(destroy		=> \&gui_exit);
	$main_wnd->signal_connect(map	=> sub {
								# initialize interface data
								users_refresh();
								groups_refresh();
								mailgroups_refresh();
							});

	$main_wnd->set_default_size(900, 640);
	$main_wnd->show_all;
	set_window_icon($main_wnd, "userman.png");

	Gtk2->main;
}


gui_main();
