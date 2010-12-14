<?php
// $Id$

// Attribute helpers

define('NO_EXPIRE', '9223372036854775807');
define('SAM_USER_OBJECT', 0x30000000);
define('SECS1610TO1970', 11644473600);
define('OLD_PASS', '~~~Q@#Rt==%%%&//z!!!');

define('ADS_UF_ACCOUNT_DISABLE', 0x2);
define('ADS_UF_PASSWD_NOT_REQUIRED', 0x20);
define('ADS_UF_NORMAL_ACCOUNT', 0x200);
define('ADS_UF_DONT_EXPIRE_PASSWD', 0x10000);

$all_attrs = array(
    // ========== user ==========
    'user' => array(
        'dn' => array(
			'type' => 'dn',
			'ldap' => 'uni',
			'label' => 'UNIX DN',
			'readonly' => 1,
		),
		'ntDn' => array(
			'type' => 'dn',
			'ldap' => 'ads',
			'label' => 'Windows DN',
			'readonly' => 1,
		),
		'cgpDn' => array(
			'type' => 'dn',
			'ldap' => 'cgp',
			'label' => 'CGP DN',
			'readonly' => 1,
		),
		'objectClass' => array(
			'type' => 'class',
			'ldap' => array( 'uni' => 'objectClass' ),
		),
		'ntObjectClass' => array(
			'type' => 'class',
			'ldap' => array( 'ads' => 'objectClass' ),
		),
		'cgpObjectClass' => array(
			'type' => 'class',
			'ldap' => array( 'cgp' => 'objectClass' ),
		),
		// ======== posixAccount... ========
		'givenName' => array(
			'label' => 'Name',
			'ldap' => 'uni,ads',
		),
		'sn' => array(
			'label' => 'Second name',
			'ldap' => 'uni,ads,cgp',
		),
		'cn' => array(
			'label' => 'Full name',
			'ldap' => 'uni,ads,cgp',
		),
		'uid' => array(
			'type' => 'number',
			'label' => 'Identifier',
			'ldap' => 'uni,ads,cgp',
		),
		'password' => array(
			'type' => 'pass',
			'label' => 'Password',
			'ldap' => array(
			    'uni' => 'userPassword',
			    'ads' => 'unicodePwd',
			    'cgp' => 'userPassword'
			),
		),
		'password2' => array(
			'type' => 'pass',
			'label' => 'Again password',
			'ldap' => array(
			    'uni' => 'userPassword',
			    'ads' => 'unicodePwd',
			    'cgp' => 'userPassword'
			),
			'verify' => 1,
		),
		'mail' => array(
			'label' => 'Mail',
			'ldap' => 'uni,ads,cgp',
		),
		'uidNumber' => array(
			'label' => 'User#',
			'ldap' => 'uni,ads',
		),
		'gidNumber' => array(
			'type' => 'gid',
			'label' => 'Group',
			'popup' => 'gid',
			'ldap' => 'uni,ads',
		),
		'moreGroups' => array(
			'type' => 'groups',
			'label' => 'Other groups',
			'popup' => 'groups',
			'ldap' => array( 'uni' => 'uid' ),
		),
		'homeDirectory' => array(
			'label' => 'Home directory',
			'ldap' =>  array( 'uni' => '', 'ads' => 'unixHomeDirectory' ),
		),
		'loginShell' => array(
			'label' => 'Login shell',
			'ldap' => 'uni,ads',
		),
		// ======== Active Directory... ========
		'accountExpires' => array(
			'default' => NO_EXPIRE,
			'ldap' => 'ads',
			'conv' => 'adtime',
			'label' => 'Expires at',
		),
		'sAMAccountName' => array(
			'ldap' => 'ads',
			'copyfrom' => 'uid',
		),
		'displayName' => array(
			'ldap' => 'ads',
			'copyfrom' => 'cn',
		),
		'instanceType' => array(
			'default' => '4',
			'ldap' => 'ads',
		),
		'userAccountControl' => array(
			'conv' => 'decihex',
			'label' => 'Account control',
			'ldap' => 'ads',
		),
		'userPrincipalName' => array(
			'ldap' => 'ads',
			'label' => 'Principal name'
		),
		'ntUserHomeDir' => array(
			'label' => 'Home directory',
			'ldap' => array( 'ntuser' => '', 'ads' => 'homeDirectory' ),
		),
		'ntUserHomeDirDrive' => array(
			'label' => 'Drive',
			'ldap' => array( 'ntuser' => '', 'ads' => 'homeDrive' ),
		),
		'ntUserProfile' => array(
			'label' => 'Profile',
			'ldap' => array( 'ntuser' => '', 'ads' => 'profilePath' ),
		),
		'ntUserScriptPath' => array(
			'label' => 'Logon script',
			'ldap' => array( 'ntuser' => '', 'ads' => 'scriptPath' ),
		),
		'PrimaryGroupID' => array(
			'type' => 'ntprig',
			'ldap' => 'ads',
		),
		'SecondaryGroups' => array(
			'type' => 'ntsecg',
			'ldap' => 'ads',
		),
		'sfuDomain' => array(
			'ldap' => array( 'ads' => 'msSFU30NisDomain' ),
		),
		'sfuName' => array(
			'ldap' => array( 'ads' => 'msSFU30Name' ),
			'copyfrom' => 'uid',
		),
		// ======== ntUser... ========
		'ntUserCreateNewAccount' => array(
			'default' => 'false',
			'ldap' => 'ntuser',
		),
		'ntUserDeleteAccount' => array(
			'default' => 'false',
			'ldap' => 'ntuser',
		),
		'ntUserAcctExpires' => array(
			'default' => NO_EXPIRE,
			'conv' => 'adtime',
			'ldap' => 'ntuser',
		),
		'ntUserLastLogon' => array(
			'conv' => 'adtime',
			'ldap' => 'ntuser',
			'disable' => 1,
		),
		'ntUserDomainId' => array(
			'ldap' => 'ntuser',
			'copyfrom' => 'uid',
			'disable' => 1,
		),
		// ======== Active Directory disabled... ========
		'ufn'			=> array( 'conv' => 'bkslash', ),
		'objectSid'     => array( 'conv' => 'binary', ),
		'objectGuid'	=> array( 'conv' => 'binary', ),
		'systemFlags'	=> array( 'conv' => 'decihex', ),
		'groupType'     => array( 'conv' => 'decihex', ),
		'whenCreated'	=> array( 'conv' => 'monotime', ),
		'whenChanged'	=> array( 'conv' => 'monotime', ),
		'pwdLastSet'	=> array( 'conv' => 'adtime', ),
		'badPasswordTime'=>array( 'conv' => 'adtime', ),
		'lastLogon'     => array( 'conv' => 'adtime', ),
		'lastLogoff'	=> array( 'conv' => 'adtime', ),
		'logonHours'	=> array( 'conv' => 'binary', ),
		'userParameters'=> array( 'conv' => 'binary', ),
		'codePage'      => array( 'default' => pack('c',0), ),
		'countryCode'   => array( 'default' => '0', ),
		'logonCount'    => array( 'default' => '0', ),
		'pwdLastSet'    => array( 'default' => '0', ),
		'objectCategory'=> array( 'disable' => 1 ),
		'samAccountType'=> array(
			'default' => SAM_USER_OBJECT,
			'conv' => 'decihex',
			'disable' => 1,
		),
		// ======== CommuniGate Pro ========
		'hostServer' => array(
			'ldap' => 'cgp',
		),
		'storageLocation' => array(
			'ldap' => 'cgp',
			'default' => '*',
		),
		'aliases' => array(
			'type' => 'aliases',
			'label' => 'Mail aliases',
			'ldap' => array( 'cgp' => 'uid' ),
		),
		'telnum' => array(
			'type' => 'none',		// (read/write via aliases)
			'label' => 'Short number',
			'ldap' => array( 'cgp' => 'uid' ),
		),
		'mailgroups' => array(
			'type' => 'mgroups',
			'label' => 'Mail groups',
			'popup' => 'mgroups',
			'ldap' => array( 'cgp' => 'uid' ),
		),
		'domainIntercept' => array(
			'type' => 'domainIntercept',
			'label' => 'Domain Intercept',
			'checkbox' => 1,
			'ldap' => array( 'cgp' => 'uid' ),
		),
		'userIntercept' => array(
			'type' => 'userIntercept',
			'label' => 'User Intercept',
			'checkbox' => 1,
			'ldap' => array( 'cgp' => 'uid' ),
		),
		// ======== Personal / Extended... ========
		'telephoneNumber' => array(
			'label' => 'Telephone',
			'ldap' => 'uni,ads',
		),
		'facsimileTelephoneNumber' => array(
			'label' => 'Fax number',
			'ldap' => 'uni,ads',
		),
		'physicalDeliveryOfficeName' => array(
			'ldap' => 'uni,ads',
		),
		'o' => array( 'ldap' => 'uni,ads', ),
		'ou' => array( 'ldap' => 'uni,ads', ),
		'label' => array( 'ldap' => 'uni,ads', ),
		'real_uidn' => array(
			'ldap' => array( 'uni' => 'uidNumber' ),
			'type' => 'real_uidn',
			'label' => 'Real user id',
			'readonly' => 1,
		),
		'real_gidn' => array(
			'ldap' => array( 'uni' => 'gidNumber' ),
			'type' => 'real_gidn',
			'label' => 'Real group id',
			'readonly' => 1,
		),
	),
	// ============ group ============
	'group' => array(
		'objectClass' => array(
			'type' => 'class',
			'ldap' => 'uni',
		),
		'dn' => array(
			'type' => 'dn',
			'ldap' => 'uni',
			'label' => 'DN'
		),
		'cn' => array(
			'label' => 'Group name',
			'ldap' => 'uni',
		),
		'gidNumber' => array(
			'label' => 'Group number',
			'ldap' => 'uni',
		),
		'description' => array(
			'label' => 'Description',
			'ldap' => 'uni',
		),
		'memberUid' => array(
			'type' => 'users',
			'label' => 'Members',
			'popup' => 'users',
			'ldap' => 'uni',
		),
	),
	// ============ mail group ============
	'mailgroup' => array(
		'dn' => array(
			'type' => 'mailgroup',
			'ldap' => 'cli',
		),
		'uid' => array(
			'type' => 'mailgroup',
			'label' => 'Group name',
			'ldap' => 'cli',
		),
		'cn' => array(
			'type' => 'mailgroup',
			'label' => 'Description',
			'ldap' => 'cli',
		),
		'groupMember' => array(
			'type' => 'mailgroup',
			'label' => 'Members',
			'popup' => 'mailusers',
			'ldap' => 'cli',
		),
		'params' => array(
			'type' => 'mailgroup',
			'ldap' => 'cli',
			'label' => 'Params',
		),
	),
	// ======== mail alias (not for creation :) ) ========
	'alias' => array(
		'objectclass' => array(
			'type' => 'class',
			'ldap' => 'cgp',
		),
		'dn' => array(
			'type' => 'dn',
			'ldap' => 'cgp',
		),
		'uid' => array(
			'ldap' => 'cgp',
		),
		'aliasedObjectName' => array(
			'ldap' => 'cgp',
		),
	),
);


$all_lc_attrs = null;


$gui_attrs = array(
	'user' => array(
		array( 'Common', array(
                'givenName', 'sn', 'cn', 'uid', 'mail', 'password', 'password2',
                'uidNumber', 'gidNumber', 'moreGroups', 'homeDirectory', 'telnum'
		)),
		array( 'Windows', array(
                'ntUserHomeDir', 'ntUserHomeDirDrive',
                'ntUserProfile', 'ntUserScriptPath',
                'userPrincipalName'
		)),
		array( 'Extended', array(
                'telephoneNumber', 'facsimileTelephoneNumber',
                'aliases', 'mailgroups',
                'domainIntercept', 'userIntercept',
                'real_uidn', 'real_gidn', 'loginShell'
		)),
	),
	'group' => array(
		array( 'Common', array(
                'cn', 'gidNumber', 'description', 'memberUid'
		)),
	),
	'mailgroup' => array(
		array( 'Common', array(
                'uid', 'cn', 'groupMember'
		)),
	),
);

$ldap_rw_subs = array(
    'none'    => array( 'ldap_read_none', 'ldap_write_none', 'ldap_write_none' ),
    'string'  => array( 'ldap_read_string', 'ldap_write_string', 'ldap_write_none' ),
    'number'  => array( 'ldap_read_string', 'ldap_write_string', 'ldap_write_none' ),
    'dn'      => array( 'ldap_read_dn', 'ldap_write_dn', 'ldap_write_none' ),
    'class'   => array( 'ldap_read_class', 'ldap_write_class', 'ldap_write_none' ),
    'pass'    => array( 'ldap_read_pass', 'ldap_write_pass', 'ldap_write_pass_final' ),
    'gid'     => array( 'ldap_read_unix_gidn', 'ldap_write_unix_gidn', 'ldap_write_none' ),
    'groups'  => array( 'ldap_read_unix_groups', 'ldap_write_none', 'ldap_write_unix_groups_final' ),
    'users'   => array( 'ldap_read_unix_members', 'ldap_write_unix_members', 'ldap_write_unix_members_final' ),
    'ntprig'  => array( 'ldap_read_ad_pri_group', 'ldap_write_ad_pri_group', 'ldap_write_none' ),
    'ntsecg'  => array( 'ldap_read_ad_sec_groups', 'ldap_write_none', 'ldap_write_ad_sec_groups_final' ),
    'aliases' => array( 'ldap_read_aliases', 'ldap_write_none', 'ldap_write_aliases_final' ),
    'mgroups' => array( 'ldap_read_mail_groups', 'ldap_write_none', 'ldap_write_mail_groups_final' ),
    'domainIntercept' => array( 'cgp_read_domain_intercept', 'ldap_write_none', 'cgp_write_domain_intercept' ),
    'userIntercept' => array( 'cgp_read_user_intercept', 'ldap_write_none', 'cgp_write_user_intercept' ),
    'mailgroup' => array( 'ldap_read_none', 'ldap_write_none', 'ldap_write_none' ),
    'real_uidn' => array( 'ldap_read_real_uidn', 'ldap_write_none', 'ldap_write_none' ),
    'real_gidn' => array( 'ldap_read_real_gidn', 'ldap_write_none', 'ldap_write_none' ),
);

function setup_all_attrs () {

    global $all_attrs;
    global $servers;
    global $ldap_rw_subs;

    $all_lc_attrs = array();

	foreach ($all_attrs as $objtype => &$descs) {

		foreach ($servers as $srv => &$cfg) {
		    $cfg['attrhash'] = array();
		    $cfg['attrhash'][$objtype] = array();
		}

		$all_lc_attrs[$objtype] = array();

        foreach ($descs as $name => &$desc) {

            $all_lc_attrs[$objtype][strtolower($name)] = $desc;

			$desc['name'] = $name;
			if (empty($desc['type']))
			    $desc['type'] = 'string';
			$desc['visual'] = isset($desc['label']);
			if (isset($desc['label']))
			    $desc['label'] = _T($desc['label']);
			if (! isset($desc['readonly']))
                $desc['readonly'] = 0;
			if (! isset($desc['verify']))
                $desc['verify'] = 0;

            if (! isset($desc['popup']))
			    $desc['popup'] = 0;
            if (! isset($desc['checkbox']))
			    $desc['checkbox'] = 0;
			if ($desc['checkbox'])
                $desc['popup'] = 'yesno';
			
			if (! isset($desc['default'])) {
                $cfg_def = "default_value_${objtype}_${name}";
                if (isset($config[$cfg_def]))
                    $desc['default'] = $config[$cfg_def];
            }

            if (! isset($desc['conv']))
                $desc['conv'] = 'none';

            foreach (array(0, 1) as $dir) {
                $sub = null;
                if (isset($convtype2subs[$desc['conv']]));
                    $sub = $convtype2subs[$desc['conv']][$dir];
                if (empty($sub))
                    $sub = 'conv_none';
                $desc[$dir ? 'disp2attr' : 'attr2disp'] = $sub;
            }

            if ($desc['copyfrom'] && !isset($descs[$desc['copyfrom']]))
                log_error('%s attribute "%s" is copy-from unknown "%s"',
                            $objtype, $name, $desc['copyfrom']);

            if (! isset($desc['disable']))
			    $desc['disable'] = 0;

			$ldap = $desc['ldap'];
			if (! is_array($ldap)) {
                $arr = split_list($ldap);
                $ldap = array();
                foreach ($arr as $val)
                    $ldap[$val] = '';
            }

			foreach (array_keys($ldap) as $srv) {
				// 'ntuser' is a special set of unix attributes
				// they can be either supported as 'uni' or unsupported
				if ($srv == 'ntuser') {
					if (get_config('ntuser_support', false)) {
                        $ldap[$srv = 'uni'] = $ldap['ntuser'];
                        unset($ldap['ntuser']);
                    } else {
                        unset($ldap['ntuser']);
                        continue;
					}
                }

                if (! isset($ldap[$srv]))
                    $ldap[$srv] = $name;

                $ldapattr = $ldap[$srv];
				$cfg = &$servers[$srv];
                if ($cfg['attrhash'][$objtype][$ldapattr])
                    log_debug('duplicate attribute "%s" as "%s" for server "%s"',
                                $name, $ldapattr, $srv);
                if (! $ldap['disable'])
                    $cfg['attrhash'][$objtype][$ldapattr] = 1;
            }

			$desc['ldap'] = $ldap;
			if (empty($ldap) || ! attribute_enabled($objtype, $name))
    			$desc['disable'] = 1;

			$subs = $ldap_rw_subs[ $desc['disable'] ? 'none' : $desc['type'] ];
			if (! $subs)
                log_error('type "%s" of "%s" attribute "%s" is not supported',
                            $desc['type'], $objtype, $name);
            $desc['ldap_read'] = $subs[0];
            $desc['ldap_write'] = $subs[1];
            $desc['ldap_write_final'] = $subs[2];
        }

        foreach ($servers as $srv => &$cfg) {
            $cfg['attrlist'][$objtype] = sort(array_keys($cfg['attrhash'][$objtype]));
        }
    }
}


function & get_attr_node ($obj, $name) {
    if (!isset($obj['a'][$name]))
        error_page(_T('attribute "%s" undefined in object "%s"', $name, $obj['type']));
    return $obj['a'][$name];
}


function create_obj ($objtype) {
    global $all_attrs;
    global $servers;
    if (! isset($all_attrs[$objtype]))
        log_error('unknown object type "%s"', $objtype);
    $descs = &$all_attrs[$objtype];
    $obj = array(
        'type' => $objtype,
        'changed' => 0,
        'a' => array(),
        'ldap' => array(),
        'attrlist' => array(),
        );
    $obj['names'] = array();
    $obj['attrs'] = array();
    foreach ($descs as $name => &$desc) {
        $at = array(
            'obj' => &$obj,
            'name' => $name,
            'desc' => &$desc,
            'type' => $desc['type'],
            'state' => null,
            'visual' => 0,
            'entry' => null,
            'bulb' => null,
        );
        $obj['a'][$name] = &$at;
        $obj['names'][] = $name;
        $obj['attrs'][] = &$at;
    }
    foreach (array_keys($servers) as $srv) {
        $obj['attrlist'][$srv] = &$servers[$srv]['attrlist'][$objtype];
    }
    return clear_obj($obj);
}


function clear_obj (&$obj) {
    foreach ($obj['attrs'] as &$at) {
        $at['val'] = $at['old'] = '';
        #if ($at['entry'])
        #    $at['entry']->set_text('');
        $at['state'] = 'empty';
    }
    global $servers;
    foreach (array_keys($servers) as $srv) {
        $obj['ldap'][$srv] = array(); # FIXME: Net::LDAP::Entry->new;
    }
    $obj['changed'] = 0;
    update_obj_gui($obj);
    return $obj;
}


function &setup_attr (&$obj, $name, $visual) {
    $at = &get_attr_node($obj, $name);
    $at['label'] = $at['entry'] = $at['bulb'] = $at['popup'] = null;
    $desc = &$at['desc'];
    $at['visual'] = $visual;
    if ($visual) {
        if (! $desc['visual'])
            log_error('%s attribute "%s" cannot be visual', $obj['type'], $name);
        #$at['label'] = Gtk2::Label->new($desc->{label});
        #$at['label']->set_justify('left');
        #$at['entry'] = Gtk2::Entry->new;
        #$at['entry']->set_editable(!$desc['disable'] && !$desc['readonly']);
        if ($at['type'] == 'pass' && !get_config('show_password')) {
            #$at['entry']->set_visibility(0);
            #$at['entry']->set_invisible_char('*');
        }
        $puptype = $desc['popup'];
        /*
        if ($puptype) {
            my $popup = create_button(undef, 'popup.png');
            $at->{popup} = $popup;
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
        */
        if (get_config('show_bulbs')) {
            #$at['bulb'] = Gtk2::Image->new;
        }
    }
    $at['val'] = $at['old'] = '';
    $at['state'] = 'empty';
    return $at;
}


function obj_changed($obj) {
    foreach ($obj['attrs'] as &$at) {
        if ($at['val'] != $at['old'])  return 1;
    }
    return 0;
}


$state2has = array(
	'force' => 0,
	'user'  => 1,
	'empty' => 0,
	'orig'  => 1,
	'calc'  => 0
    );

function has_attr ($obj, $name) {
    $at = &get_attr_node($obj, $name);
    $state = nvl($at['state']);
    global $state2has;
    if (isset($state2has[$state]))
        return $state2has[$state];
    return nvl($at['val']) != '' ? 1 : 0;
}


function get_attr ($obj, $name, $param = array()) {
    $at = &get_attr_node($obj, $name);
    $which = (isset($param['orig']) && $param['orig']) ? 'old' : 'val';
    return nvl($at[$which]);
}


function set_attr ($obj, $name, $val, $param = array()) {
    $at = &get_attr_node($obj, $name);
    $val = nvl($val);
    if ($at->{val} == $val)
        return $at;
    $at['val'] = $val;

    if ($val == '') {
        $state = 'empty';
    } else if ($val == $at['old']) {
        $state = 'orig';
    #} else if (isset($at['entry']) && ($val == nvl($at['entry']->get_text())) ) {
    #    $state = 'user';
    } else {
        $state = 'calc';
    }
    $at['state'] = $state;

    $sdn = nvl(get_attr($obj, 'dn'));
    $parts = array();
    $sdn = preg_match('/^\s*(.*?)\s*,/', $sdn, $parts) ? $parts[1] : '???';
    log_debug('(%s): [%s] := (%s)', $sdn, $name, $val);

    return $at;
}


function cond_set ($obj, $name, $val) {
    $has = has_attr($obj, $name);
    $node = get_attr_node($obj, $name);
    if ($node['desc']['disable'])
        return 0;
    if (! $has)
        set_attr($obj, $name, $val);
    return $has;
}


function init_attr ($obj, $name, $val) {
    $at = &get_attr_node($obj, $name);
    $val = nvl($val);
    if ($val == '') {
        $at['state'] = 'empty';
    } else {
        $at['val'] = $at['old'] = $val;
        $at['state'] = 'orig';
    }
    #if (isset($at['entry']))
    #    $at['entry']->set_text($at->{val});
    return $at;
}


?>
