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

        // Read/write methods, per server, per-operation
        // array means LDAP-driven action and contains parts of LDAP request
        // if value is not an array, the string contains relevant function
        '_accessors' => array(
            'uni' => array(
                        'read' => array('objectClass' => 'person', 'uid' => '$(_ID)'),
                        'write' => array(),
                        'list' => array('objectClass' => 'person')
                        ),
            'ads' => array(
                        'read' => array('objectClass' => 'user', 'cn' => '$(cn)'),
                        'prewrite' => 'ad_fix_update_data',
                        'write' => array()
                        ),
            'cgp' => array(
                        'read' => 'cgp_user_reader',
                        'write' => 'cgp_user_writer',
                        'clean' => 'cgp_user_cleaner'
                        )
        ),

        // ======== posixAccount... ========

        'dn' => array(
            'type' => 'dn',
            'srv' => 'uni',
            'label' => 'UNIX DN',
        ),
        'objectClass' => array(
            'type' => 'class',
            'srv' => 'uni',
        ),
        'uid' => array(
            'type' => 'number',
            'label' => 'Identifier',
            'srv' => array(
                'uni' => '',
                'ads' => '',
                'cgp' => '_cgp_id'
            ),
            'colwidth' => 120,
        ),
        'givenName' => array(
            'label' => 'Name',
            'srv' => 'uni,ads',
        ),
        'sn' => array(
            'label' => 'Second name',
            'srv' => array(
                'uni' => '',
                'ads' => '',
                'cgp' => 'surname'
            ),
        ),
        'cn' => array(
            'label' => 'Full name',
            'srv' => array(
                'uni' => '',
                'ads' => '',
                'cgp' => 'RealName'
            ),
            'colwidth' => 160,
        ),
        'password' => array(
            'type' => 'pass',
            'label' => 'Password',
            'srv' => 'uni,ads,cgp',
        ),
        'password2' => array(
            'type' => 'pass',
            'label' => 'Again password',
            'readonly' => true,
            'srv' => array(
                'uni' => 'userPassword',
                'ads' => 'unicodePwd',
                'cgp' => 'Password'
            ),
        ),
        'uidNumber' => array(
            'label' => 'User#',
            'srv' => 'uni,ads',
        ),
        'gidNumber' => array(
            'type' => array( 'unix_read_gidn', 'unix_write_gidn', null ),
            'label' => 'Group',
            'popup' => 'gid',
            'srv' => 'uni,ads',
        ),
        'moreGroups' => array(
            'type' => array( 'unix_read_user_groups', null, 'unix_write_user_groups_final' ),
            'label' => 'Other groups',
            'popup' => 'groups',
            'srv' => 'uni',
        ),
        'homeDirectory' => array(
            'label' => 'Home directory',
            'srv' =>  array( 'uni' => '', 'ads' => 'unixHomeDirectory' ),
        ),
        'loginShell' => array(
            'label' => 'Login shell',
            'srv' => 'uni,ads',
        ),

        // ======== Active Directory... ========

        'ntDn' => array(
            'type' => 'dn',
            'srv' => array('ads' => 'dn'),
        ),
        'ntObjectClass' => array(
            'type' => 'class',
            'srv' => array('ads' => 'objectClass'),
        ),
        'accountExpires' => array(
            'defval' => NO_EXPIRE,
            'srv' => 'ads',
            'conv' => 'adtime',
            'label' => 'Expires at',
        ),
        'sAMAccountName' => array(
            'srv' => 'ads',
            'copyfrom' => 'uid',
        ),
        'displayName' => array(
            'srv' => 'ads',
            'copyfrom' => 'cn',
        ),
        'instanceType' => array(
            'defval' => '4',
            'srv' => 'ads',
        ),
        'userAccountControl' => array(
            'conv' => 'decihex',
            'srv' => 'ads',
        ),
        'userPrincipalName' => array(
            'srv' => 'ads',
            'label' => 'Principal name'
        ),
        'ntUserHomeDir' => array(
            'label' => 'Home directory',
            'srv' => array( 'ntuser' => '', 'ads' => 'homeDirectory' ),
        ),
        'ntUserHomeDirDrive' => array(
            'label' => 'Drive',
            'srv' => array( 'ntuser' => '', 'ads' => 'homeDrive' ),
        ),
        'ntUserProfile' => array(
            'label' => 'Profile',
            'srv' => array( 'ntuser' => '', 'ads' => 'profilePath' ),
        ),
        'ntUserScriptPath' => array(
            'label' => 'Logon script',
            'srv' => array( 'ntuser' => '', 'ads' => 'scriptPath' ),
        ),
        'PrimaryGroupID' => array(
            'type' => array( 'ad_read_pri_group', 'ad_write_pri_group', null ),
            'srv' => 'ads',
        ),
        'SecondaryGroups' => array(
            'type' => array( 'ad_read_sec_groups', null, 'ad_write_sec_groups_final' ),
            'srv' => 'ads',
        ),
        'sfuDomain' => array(
            'srv' => array( 'ads' => 'msSFU30NisDomain' ),
        ),
        'sfuName' => array(
            'srv' => array( 'ads' => 'msSFU30Name' ),
            'copyfrom' => 'uid',
        ),

        // ======== ntUser... ========
        // 'ntuser' is a special set of unix attributes
        // they can be either supported as 'uni' or unsupported

        'ntUserCreateNewAccount' => array(
            'defval' => 'false',
            'srv' => 'ntuser',
        ),
        'ntUserDeleteAccount' => array(
            'defval' => 'false',
            'srv' => 'ntuser',
        ),
        'ntUserAcctExpires' => array(
            'defval' => NO_EXPIRE,
            'conv' => 'adtime',
            'srv' => 'ntuser',
        ),
        'ntUserLastLogon' => array(
            'conv' => 'adtime',
            'srv' => 'ntuser',
            'disable' => true,
        ),
        'ntUserDomainId' => array(
            'srv' => 'ntuser',
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

        'mail' => array(
            'label' => 'Mail',
            'srv' => array(
                'uni' => '',
                'ads' => '',
                'cgp' => '_cgp_mail'
            )
        ),
        'aliases' => array(
            'type' => array( 'cgp_read_aliases', null, 'cgp_write_aliases_final' ),
            'label' => 'Mail aliases',
            'srv' => 'cgp',
        ),
        'telnum' => array(
            'type' => 'none',           // cgp_read_aliases/cgp_write_aliases handles this value
            'label' => 'Short number',
            'srv' => 'cgp',
        ),
        'mailgroups' => array(
            'type' => array( 'cgp_read_user_mail_groups', null, 'cgp_write_user_mail_groups_final' ),
            'label' => 'Mail groups',
            'popup' => 'mailgroups',
            'srv' => 'cgp',
        ),
        'domainIntercept' => array(
            'type' => array( 'cgp_read_domain_intercept', null, 'cgp_write_domain_intercept_final' ),
            'label' => 'Domain Intercept',
            'checkbox' => true,
            'disable' => true,
            'srv' => 'cgp',
        ),
        'userIntercept' => array(
            'type' => array( 'cgp_read_user_intercept', null, 'cgp_write_user_intercept_final' ),
            'label' => 'User Intercept',
            'checkbox' => true,
            'srv' => 'cgp',
        ),

        // ======== Personal / Extended... ========

        'telephoneNumber' => array(
            'label' => 'Telephone',
            'srv' => 'uni,ads',
        ),
        'facsimileTelephoneNumber' => array(
            'label' => 'Fax number',
            'srv' => 'uni,ads',
        ),
        'physicalDeliveryOfficeName' => array(
            'srv' => 'uni,ads',
        ),
        'o' => array( 'srv' => 'uni,ads', ),
        'ou' => array( 'srv' => 'uni,ads', ),
        'label' => array( 'srv' => 'uni,ads', ),
        'real_uidn' => array(
            'srv' => array( 'uni' => 'uidNumber' ),
            'type' => array( 'posix_read_real_uidn', null, null ),
            'label' => 'Real user id',
            'readonly' => true,
        ),
        'real_gidn' => array(
            'srv' => array( 'uni' => 'gidNumber' ),
            'type' => array( 'posix_read_real_gidn', null, null ),
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
                        'read' => array('objectClass' => 'posixGroup', 'cn' => '$(_ID)'),
                        'write' => array(),
                        'list' => array('objectClass' => 'posixGroup')
                        )
        ),

        'objectClass' => array(
            'type' => 'class',
            'srv' => 'uni',
        ),
        'dn' => array(
            'type' => 'dn',
            'srv' => 'uni',
            'label' => 'DN'
        ),
        'cn' => array(
            'label' => 'Group name',
            'srv' => 'uni',
            'colwidth' => 130,  // mark for inclusion in the list panel
        ),
        'gidNumber' => array(
            'label' => 'Group number',
            'srv' => 'uni',
        ),
        'description' => array(
            'label' => 'Description',
            'srv' => 'uni',
        ),
        'memberUid' => array(
            'type' => array( 'unix_read_group_members', 'unix_write_group_members', null ),
            'label' => 'Members',
            'popup' => 'users',
            'srv' => 'uni',
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
                    'write' => 'cgp_mailgroup_writer',
                    'list' => 'cgp_mailgroup_list'
                    )
        ),

        'uid' => array(
            'type' => array( 'cgp_read_mailgroup_uid', null, null ),
            'label' => 'Group name',
            'srv' => 'cgp',
            'colwidth' => 140,  // mark for inclusion in the list panel
        ),
        'cn' => array(
            'label' => 'Description',
            'srv' => array( 'cgp' => 'RealName' ),
        ),
        'groupMember' => array(
            'type' => array( 'cgp_read_mailgroup_members', 'cgp_write_mailgroup_members', null ),
            'label' => 'Members',
            'popup' => 'mailusers',
            'srv' => 'cgp',
        ),
        'params' => array(
            'type' => array( 'cgp_read_mailgroup_params', 'cgp_write_mailgroup_params', null ),
            'label' => 'Params',
            'srv' => 'cgp',
        ),
    ),

    // ======== mail alias (not for creation :) ) ========

    'alias' => array(
        'uid' => array( 'srv' => 'cgp' ),
        'aliasedObjectName' => array( 'srv' => 'cgp' )
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
    'none'    => array( null, null, null ),
    'string'  => array( 'ldap_read_string', 'ldap_write_string', null ),
    'number'  => array( 'ldap_read_string', 'ldap_write_string', null ),
    'dn'      => array( 'ldap_read_dn', 'ldap_write_dn', null ),
    'class'   => array( 'ldap_read_class', 'ldap_write_class', null ),
    'pass'    => array( 'ldap_read_pass', 'ldap_write_pass', 'ldap_write_pass_final' )
    );


//
// Some attributes are disabled depending on configuration
//
function attribute_enabled ($objtype, $name) {
    if ($objtype == 'user') {
        if ($name == 'password2' && str2bool(get_config('show_password')))
            return false;
        if ($name == 'real_uidn' || $name == 'real_gidn') {
            if (! get_config('prefer_nss_ids'))
                return false;
        }
    }
    return true;
}

?>
