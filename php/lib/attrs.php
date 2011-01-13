<?php
// $Id$

// Attribute descriptors

define('NO_EXPIRE', '9223372036854775807');
define('SAM_USER_OBJECT', 0x30000000);
define('SECS1610TO1970', 11644473600);
define('OLD_PASS', '~~~Q@#Rt==%%%&//z!!!');

define('ADS_UF_ACCOUNT_DISABLE', 0x2);
define('ADS_UF_PASSWD_NOT_REQUIRED', 0x20);
define('ADS_UF_NORMAL_ACCOUNT', 0x200);
define('ADS_UF_DONT_EXPIRE_PASSWD', 0x10000);


$all_attrs = array(

    /////////////////////////////////////////////
    // ================   user   ===============
    /////////////////////////////////////////////

    'user' => array(

        // Read/write methods
        '_accessors' => array(
            'uni' => array(
                        'read' => array('objectClass' => 'person', 'uid' => '$_ID'),
                        'write' => 'LDAP'
                        ),
            'ads' => array(
                        'read' => array('objectClass' => 'user', 'cn' => '$cn'),
                        'write' => 'LDAP'
                        ),
            'cgp' => array(
                        'read' => 'cgp_user_reader',
                        'write' => 'cgp_user_writer'
                        )
        ),

        // ======== Core... ========

        'dn' => array(
            'type' => 'dn',
            'ldap' => 'uni',
            'label' => 'UNIX DN',
            'readonly' => true,
        ),
        'ntDn' => array(
            'type' => 'dn',
            'ldap' => 'ads',
            'label' => 'Windows DN',
            'readonly' => true,
        ),
        'objectClass' => array(
            'type' => 'class',
            'ldap' => array( 'uni' => 'objectClass' ),
        ),
        'ntObjectClass' => array(
            'type' => 'class',
            'ldap' => array( 'ads' => 'objectClass' ),
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
            'colwidth' => 160,
        ),
        'uid' => array(
            'type' => 'number',
            'label' => 'Identifier',
            'ldap' => 'uni,ads,cgp',
            'colwidth' => 120,
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
            'verify' => true,
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
            'type' => array( 'ldap_read_unix_gidn', 'ldap_write_unix_gidn', 'ldap_write_none' ),
            'label' => 'Group',
            'popup' => 'gid',
            'ldap' => 'uni,ads',
        ),
        'moreGroups' => array(
            'type' => array( 'ldap_read_unix_groups', 'ldap_write_none', 'ldap_write_unix_groups_final' ),
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
            'defval' => NO_EXPIRE,
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
            'defval' => '4',
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
            'type' => array( 'ad_read_pri_group', 'ad_write_pri_group', 'ldap_write_none' ),
            'ldap' => 'ads',
        ),
        'SecondaryGroups' => array(
            'type' => array( 'ad_read_sec_groups', 'ldap_write_none', 'ad_write_sec_groups_final' ),
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
            'defval' => 'false',
            'ldap' => 'ntuser',
        ),
        'ntUserDeleteAccount' => array(
            'defval' => 'false',
            'ldap' => 'ntuser',
        ),
        'ntUserAcctExpires' => array(
            'defval' => NO_EXPIRE,
            'conv' => 'adtime',
            'ldap' => 'ntuser',
        ),
        'ntUserLastLogon' => array(
            'conv' => 'adtime',
            'ldap' => 'ntuser',
            'disable' => true,
        ),
        'ntUserDomainId' => array(
            'ldap' => 'ntuser',
            'copyfrom' => 'uid',
            'disable' => true,
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
        'codePage'      => array( 'defval' => pack('c',0), ),
        'countryCode'   => array( 'defval' => '0', ),
        'logonCount'    => array( 'defval' => '0', ),
        'pwdLastSet'    => array( 'defval' => '0', ),
        'objectCategory'=> array( 'disable' => true ),
        'samAccountType'=> array(
            'defval' => SAM_USER_OBJECT,
            'conv' => 'decihex',
            'disable' => true,
        ),

        // ======== CommuniGate Pro ========

        'mailuser' => array(
            'type' => array( 'cgp_read_user', 'cgp_write_user', 'ldap_write_none' ),
            'ldap' => 'cgp',
        ),
        'aliases' => array(
            'type' => array( 'cgp_read_aliases', 'ldap_write_none', 'cgp_write_aliases_final' ),
            'label' => 'Mail aliases',
            'ldap' => 'cgp',
        ),
        'telnum' => array(
            'type' => 'none',           // read/write via aliases
            'label' => 'Short number',
            'ldap' => 'cgp',
        ),
        'mailgroups' => array(
            'type' => array( 'cgp_read_mail_groups', 'ldap_write_none', 'cgp_write_mail_groups_final' ),
            'label' => 'Mail groups',
            'popup' => 'mailgroups',
            'ldap' => 'cgp',
        ),
        'domainIntercept' => array(
            'type' => 'domainIntercept',
            'label' => 'Domain Intercept',
            'checkbox' => true,
            'disable' => true,
            'ldap' => 'cgp',
        ),
        'userIntercept' => array(
            'type' => 'userIntercept',
            'label' => 'User Intercept',
            'checkbox' => true,
            'ldap' => 'cgp',
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
            'readonly' => true,
        ),
        'real_gidn' => array(
            'ldap' => array( 'uni' => 'gidNumber' ),
            'type' => 'real_gidn',
            'label' => 'Real group id',
            'readonly' => true,
        ),
    ),

    /////////////////////////////////////////////
    // ==============   group   ================
    /////////////////////////////////////////////

    'group' => array(

        // Read/write methods
        '_accessors' => array(
            'uni' => array(
                        'read' => array('objectClass' => 'posixGroup', 'cn' => '$_ID'),
                        'write' => 'LDAP'
                        )
        ),

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
            'colwidth' => 130,  // mark for inclusion in the list panel
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
            'type' => array( 'ldap_read_unix_members', 'ldap_write_unix_members', 'ldap_write_none' ),
            'label' => 'Members',
            'popup' => 'users',
            'ldap' => 'uni',
        ),
    ),

    /////////////////////////////////////////////
    // ============   mail group   =============
    /////////////////////////////////////////////

    'mailgroup' => array(

        // Read/write methods
        '_accessors' => array(
            'cgp' => array(
                    'read' => 'cgp_mailgroup_reader',
                    'write' => 'cgp_mailgroup_writer'
                    )
        ),

        'uid' => array(
            'type' => array( 'cgp_read_mailgroup_uid', 'ldap_write_none', 'ldap_write_none' ),
            'label' => 'Group name',
            'ldap' => 'cgp',
            'colwidth' => 140,  // mark for inclusion in the list panel
        ),
        'cn' => array(
            'label' => 'Description',
            'ldap' => array( 'cgp' => 'RealName' ),
        ),
        'groupMember' => array(
            'type' => array( 'cgp_read_mailgroup_members', 'cgp_write_mailgroup_members', 'ldap_write_none' ),
            'label' => 'Members',
            'popup' => 'mailusers',
            'ldap' => 'cgp',
        ),
        'params' => array(
            'type' => array( 'cgp_read_mailgroup_params', 'cgp_write_mailgroup_params', 'ldap_write_none' ),
            'label' => 'Params',
            'ldap' => 'cgp',
        ),
    ),

    // ======== mail alias (not for creation :) ) ========

    'alias' => array(
        'uid' => array(
            'ldap' => 'cgp',
        ),
        'aliasedObjectName' => array(
            'ldap' => 'cgp',
        ),
    ),
);


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
        ))
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


$data_accessors = array(
    'none'    => array( 'ldap_read_none', 'ldap_write_none', 'ldap_write_none' ),
    'string'  => array( 'ldap_read_string', 'ldap_write_string', 'ldap_write_none' ),
    'number'  => array( 'ldap_read_string', 'ldap_write_string', 'ldap_write_none' ),
    'dn'      => array( 'ldap_read_dn', 'ldap_write_dn', 'ldap_write_none' ),
    'class'   => array( 'ldap_read_class', 'ldap_write_class', 'ldap_write_none' ),
    'pass'    => array( 'ldap_read_pass', 'ldap_write_pass', 'ldap_write_pass_final' ),
    'domainIntercept' => array( 'cgp_read_domain_intercept', 'ldap_write_none', 'cgp_write_domain_intercept' ),
    'userIntercept' => array( 'cgp_read_user_intercept', 'ldap_write_none', 'cgp_write_user_intercept' ),
    'real_uidn' => array( 'posix_read_real_uidn', 'ldap_write_none', 'ldap_write_none' ),
    'real_gidn' => array( 'posix_read_real_gidn', 'ldap_write_none', 'ldap_write_none' ),
    );


$data_converters = array(
    'none'      => array('conv_none', 'conv_none'),
    'bkslash'   => array('bkslash_front', 'bkslash_back'),
    'binary'    => array('binary_front', 'binary_back'),
    'monotime'  => array('monotime_front', 'monotime_back'),
    'decihex'	=> array('decihex_front', 'decihex_back'),
    'adtime'	=> array('adjtime_front', 'adjtime_back')
    );


function attribute_enabled ($objtype, $name) {
    if ($objtype == 'user') {
        if ($name == 'password2' && get_config('show_password'))
            return false;
        if ($name == 'real_uidn' || $name == 'real_gidn') {
            if (! get_config('prefer_nss_ids'))
                return false;
        }
    }
    return true;
}


?>
