<?php
// $Id$


//////////////////////////////////////////////////////////////
// Active Directory
//


function encode_ad_pass ($pass) {
    $encoded = array();
    foreach (preg_split('//', '"' . $pass . '"', -1, PREG_SPLIT_NO_EMPTY) as $c) {
        $encoded[] = $c;
        $encoded[] = 0;
    }
    return pack('c*', $encoded);
}


function decode_ad_pass ($pass) {
    $chars = unpack('c*', $pass);
    $decoded = '';
    $n = count($chars);
    for ($i = 0; $i < $n; $i++) {
        if (($i == 0 || $i == $n - 1) && $chars[$i] == '"') // FIXME ord?
            continue;
        if ($c != 0) // FIXME ord?
            $decoded .= $c;
    }
    return $decoded;
}


function ad_read_pri_group (&$obj, &$at, $srv, &$ldap, $name) {
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


function ad_write_pri_group (&$obj, &$at, $srv, &$ldap, $name, $val) {
	// writing not supported: AD refuses to set PrimaryGroupID
	return 0;
}


function ad_read_sec_groups (&$obj, &$at, $srv, &$ldap, $name) {
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


function ad_write_sec_groups_final (&$obj, &$at, $srv, &$ldap, $name, $val) {
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
