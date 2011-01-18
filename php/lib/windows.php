<?php
// $Id$


//////////////////////////////////////////////////////////////
// Active Directory
//


//
// There are some attributes that Windows returns during reads but hates
// when we UPDATE them (at least from PHP, I recall it worked from Perl).
// As a workaround I completely wipe them off the data record.
//
function ad_fix_update_data (&$obj, $srv, $id, $idold, &$data) {
    static $offenders = array('cn', 'objectClass', 'instanceType');
    if (!empty($idold)) {
        // if updating
        foreach ($offenders as $name)
            uldap_delete($data, $name);
    }
    return array('code' => 0);
}


function ad_write_pass_final (&$obj, &$at, $srv, &$data, $name, $val) {
    // encode password to unicode for active directory
    $enc = "";
    foreach (str_split("\"$val\"") as $ch)  $enc .= "$ch\000";

    $dn = uldap_dn($data);
    $res = uldap_entry_update($srv, $dn, array('unicodePwd' => $enc));
    if ($res['code']) {
        $obj['msg'][] = log_error('ad_write_pass_final(%s) [%s] error: %s',
                                    $srv, $dn, $res['error']);
        return false;
    }

    log_debug('ad_write_pass_final(%s) [%s] OK', $srv, $dn);
    return true;
}


function ad_read_pri_group (&$obj, &$at, $srv, &$data, $name) {
	return 0;
/*
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
*/
}


function ad_write_pri_group (&$obj, &$at, $srv, &$data, $name, $val) {
	// writing not supported: AD refuses to set PrimaryGroupID
	return 0;
}


function ad_read_sec_groups (&$obj, &$at, $srv, &$data, $name) {
	return '';
/*
    my $filter = join( '', map("(cn=$_)", split_list $config{ad_user_groups}) );
    my $res = ldap_search($srv, "(&(objectClass=group)(|$filter))");
    if ($res->code) {
        message_box('error', 'close',
            _T('Error reading list of Windows groups: %s', $res->error));
    }
    return join_list map { $_->get_value('name') } $res->entries;
*/
}


function ad_write_sec_groups_final (&$obj, &$at, $srv, &$data, $name, $val) {
	return 0;
/*
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
*/
}


?>
