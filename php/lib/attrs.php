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
                        'read' => array('objectClass' => 'person', 'uid' => '$_ID'),
                        'write' => array(),
                        'list' => array('objectClass' => 'person')
                        ),
            'ads' => array(
                        'read' => array('objectClass' => 'user', 'cn' => '$cn'),
                        'write' => array()
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
            'ldap' => 'uni',
        ),
        'ntObjectClass' => array(
            'type' => 'class',
            'ldap' => 'ads',
        ),

        // ======== posixAccount... ========

        'uid' => array(
            'type' => 'number',
            'label' => 'Identifier',
            'ldap' => 'uni,ads,cgp',
            'colwidth' => 120,
        ),
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
            'type' => array( 'ldap_read_unix_gidn', 'ldap_write_unix_gidn', null ),
            'label' => 'Group',
            'popup' => 'gid',
            'ldap' => 'uni,ads',
        ),
        'moreGroups' => array(
            'type' => array( 'ldap_read_unix_groups', null, 'ldap_write_unix_groups_final' ),
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
            'type' => array( 'ad_read_pri_group', 'ad_write_pri_group', null ),
            'ldap' => 'ads',
        ),
        'SecondaryGroups' => array(
            'type' => array( 'ad_read_sec_groups', null, 'ad_write_sec_groups_final' ),
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
        // 'ntuser' is a special set of unix attributes
        // they can be either supported as 'uni' or unsupported

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
            'type' => array( 'cgp_read_user', 'cgp_write_user', null ),
            'ldap' => 'cgp',
        ),
        'aliases' => array(
            'type' => array( 'cgp_read_aliases', null, 'cgp_write_aliases_final' ),
            'label' => 'Mail aliases',
            'ldap' => 'cgp',
        ),
        'telnum' => array(
            'type' => 'none',           // read/write is done by aliases
            'label' => 'Short number',
            'ldap' => 'cgp',
        ),
        'mailgroups' => array(
            'type' => array( 'cgp_read_mail_groups', null, 'cgp_write_mail_groups_final' ),
            'label' => 'Mail groups',
            'popup' => 'mailgroups',
            'ldap' => 'cgp',
        ),
        'domainIntercept' => array(
            'type' => array( 'cgp_read_domain_intercept', null, 'cgp_write_domain_intercept' ),
            'label' => 'Domain Intercept',
            'checkbox' => true,
            'disable' => true,
            'ldap' => 'cgp',
        ),
        'userIntercept' => array(
            'type' => array( 'cgp_read_user_intercept', null, 'cgp_write_user_intercept' ),
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
            'type' => array( 'posix_read_real_uidn', null, null ),
            'label' => 'Real user id',
            'readonly' => true,
        ),
        'real_gidn' => array(
            'ldap' => array( 'uni' => 'gidNumber' ),
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
                        'read' => array('objectClass' => 'posixGroup', 'cn' => '$_ID'),
                        'write' => array(),
                        'list' => array('objectClass' => 'posixGroup')
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
            'type' => array( 'ldap_read_unix_members', 'ldap_write_unix_members', null ),
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
                    'write' => 'cgp_mailgroup_writer',
                    'list' => 'cgp_mailgroup_list'
                    )
        ),

        'uid' => array(
            'type' => array( 'cgp_read_mailgroup_uid', null, null ),
            'label' => 'Group name',
            'ldap' => 'cgp',
            'colwidth' => 140,  // mark for inclusion in the list panel
        ),
        'cn' => array(
            'label' => 'Description',
            'ldap' => array( 'cgp' => 'RealName' ),
        ),
        'groupMember' => array(
            'type' => array( 'cgp_read_mailgroup_members', 'cgp_write_mailgroup_members', null ),
            'label' => 'Members',
            'popup' => 'mailusers',
            'ldap' => 'cgp',
        ),
        'params' => array(
            'type' => array( 'cgp_read_mailgroup_params', 'cgp_write_mailgroup_params', null ),
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
