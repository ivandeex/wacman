<?php
// $Id$


//////////////////////////////////////////////////////////////
// Unix OpenLDAP
//

function ldap_read_unix_gidn (&$at, $srv, $ldap, $name) {
    $val = nvl(uldap_value($ldap, $at['name']));
	if (is_int($val)) {
        $res = uldap_search($ldap, 'uni', "(&(objectClass=posixGroup)(gidNumber=$val))");
        $grp = $res[0];
        if ($grp) {
            $cn = uldap_value($grp, 'cn');
            if (! empty($cn))
                $val = $cn;
        } else {
            log_debug('cannot find group id %d (error: %s)', $val, $res->error);
        }
    }
    return $val;
}


function ldap_write_unix_gidn (&$at, $srv, $ldap, $name, $val) {
    if (!empty($val) && !is_int($val)) { // /^\d*$/
        $cn = $val;
        $val = 0;
        $res = uldap_search('uni', "(&(objectClass=posixGroup)(cn=$cn))", array('gidNumber'));
        $grp = $res[0];
        if ($grp) {
            $gidn = uldap_value($grp, 'gidNumber');
            if ($gidn)
                $val = $gidn;
        }
        if (! $val)
            log_info('ldap_write_gidn: group "%s" not found on %s', $cn);
    }
    log_debug('ldap_write_gidn: set group to "%s"', $val);
    return ldap_write_string ($at, $srv, $ldap, $name, $val);
}


function unix_write_pass_final (&$at, $srv, $ldap, $name, $val) {
    global $servers;
    $conf =& $servers[$srv];
    $ldap =& $conf['ldap'];
    if (! isset($conf['extop'])) {
        $conf['extop'] = false; # FIXME $ldap->root_dse->supported_extension('1.3.6.1.4.1.4203.1.11.1');
    }
    $extop = $conf['extop'];
    $obj =& $at['obj'];
    $dn = get_attr($obj, 'dn');
    if ($extop) {
        // set_password() without 'oldpasswd' works only for administrator
        // ordinary users need to supply 'oldpasswd'
        #$res = $ldap->set_password(user => $dn, newpasswd => $val);
    } else {
        // 'replace' works only for administrator.
        // unprivileged users need to use change(delete=old,add=new)
        $res = uldap_modify($ldap, $dn, $name, $val);
    }
    log_debug('change password on "%s": dn="%s" extop=%d attr=%s code=%d',
                $srv, $dn, $extop, $name, $res['code']);
    if ($res['code']) {
        message_box('error', 'close',
                    _T('Cannot change password for "%s" on "%s": %s',
                        $dn, $srv, $res['error']));
        return 0;
    }
    return 1;
}


function ldap_read_unix_groups (&$at, $srv, $ldap, $name) {
    $uid = nvl(uldap_value($ldap, $name));
    if (!isset($uid) || !$uid)
        $uid = get_attr($at['obj'], $name);
    $entries = uldap_search($srv, "(&(objectClass=posixGroup)(memberUid=$uid))", array('cn'));
    $arr = array();
    foreach ($entries as $e)
        $arr[] = uldap_value($e, 'cn');
    return join_list($arr);
}


function ldap_get_unix_group_ids ($srv, $val, $warn, $asstring = false) {
    $a_ids = split_list($val);
    #log_debug('list for "%s" is "%s"', $val, join_list($ids));
    if (empty($a_ids)) {
        return $asstring ? '' : array();
    }
    $h_ids = array();
    foreach ($a_ids as $x)
        $h_ids[$x] = 1;
    $gidns = array();
    $s_arr = array();
    foreach ($a_ids as $x)
        $s_arr[] = is_int($x) ? "(cn=$x)(gidNumber=$x)" : "(cn=$x)";
    $s = join('', $s_arr);
    $s = "(&(objectClass=posixGroup)(|$s))";
    log_debug('request for "%s" is "%s"', $val, $s);
    $entries = uldap_search($srv, $s, array('cn', 'gidNumber'));
    foreach ($entries as $grp) {
        $gidn = uldap_value($grp, 'gidNumber');
        $cn = uldap_value($grp, 'cn');
        unset($h_ids[$gidn]);
        unset($h_ids[$cn]);
        $gidns[] = $gidn;
    }
    // FIXME remove unset values from array
    if ($warn == 'warn' && count($h_ids) > 0)
        message_box('error', 'close', _T('Groups not found: %s', join_list(array_keys($h_ids))));
    $gidns = sort($gidns);
    log_debug('group list for "%s" is "%s"', $val, join_list($gidns));
    return $gidns;
}


function ldap_modify_unix_group ($srv, $gidn, $uid, $action) {
    log_debug('will be %s\'ing unix user "%s" in group %d...',  $action, $uid, $gidn);    
    $entries = uldap_search('uni', "(&(objectClass=posixGroup)(gidNumber=$gidn))", array('memberUid'));
    $grp = $res[0];
    if ($res['code'] || !$grp) {
        log_info('cannot find unix group %d for modification', $gidn);
        return $res['error'];
    }
    $exists = uldap_exists($grp, 'memberUid');
    $old = $exists ? join_list(uldap_value($grp, 'memberUid')) : '';
    $new = $action == 'add' ? append_list($old, $uid) : remove_list($old, $uid);
    $a_new = split_list($new);
    if ($old == $new) {
        log_debug('unix group %d wont change with user "%s": (%s) = (%s)',
                    $gidn, $uid, $old, $new);
        return 'SAME';
    }
    if ($exists) {
        uldap_replace($grp, 'memberUid', $a_new);
    } else {
        uldap_add($grp, 'memberUid', $a_new);
    }
    $res = ldap_update('uni', $grp);
    if ($res['code']) {
        log_info('%s unix user "%s" in group %d error: %s',
                    $action, $uid, $gidn, $res['error']);
        $retval = $res['error'];
    } else {
        log_debug('success %s\'ing unix user "%s" in group %d: [%s] -> [%s]...',
                    $action, $uid, $gidn, $old, $new);
        $retval = 'OK';
    }
    $sel_grp = $group_obj;
    if (!$sel_grp['changed'] && get_attr($sel_grp, 'gidNumber') == $gidn) {
        // refresh gui for this group
        group_load();
    }
    return $retval;
}


function ldap_write_unix_groups_final (&$at, $srv, $ldap, $name, $val) {
    $uid = get_attr($at['obj'], $name);
    $old = ldap_get_unix_group_ids($srv, $at['old'], 'nowarn'); # FIXME!!!
    $new = ldap_get_unix_group_ids($srv, $at['val'], 'warn');
    log_debug('write_unix_groups(1): old=(%s) new=(%s)', $old, $new);
    $arr = compare_lists($old, $new);
    $old = $arr[0];
    $new = $arr[1];
    log_debug('write_unix_groups(2): del=(%s) add=(%s)', $old, $new);
    foreach (split_list($old) as $gidn) {
        ldap_modify_unix_group($srv, $gidn, $uid, 'remove');
    }
    foreach (split_list($new) as $gidn) {
        ldap_modify_unix_group($srv, $gidn, $uid, 'add');
    }
    return ($old != '' || $new != '');
}


function ldap_read_unix_members (&$at, $srv, $ldap, $name) {
    // RHDS returns uid numbers, OpenLDAP returns usernames. We handle both cases.
    $uidns = uldap_value($ldap, $name, true);
    log_debug('ldap_read_unix_members: "%s" is (%s)', $name, join_list($uidns));
    $uids = array();
    foreach ($uidns as $uidn) {
        if (preg_match('!^\d+$!', $uidn)) {
            $res = uldap_search($srv, "(&(objectClass=person)(uidNumber=$uidn))", array('uid'));
            $ue = $res['data'];
            $uid = $ue ? nvl(uldap_value($ue, 'uid')) : '';
            $uids[] = empty($uid) ? $uidn : $uid;
        } else {
            $uids[] = $uidn;
        }
    }
    $val = join_list($uids);
    log_debug('ldap_read_unix_members: "%s" returns "%s"...', $name, $val);
    return $val;
}


function ldap_write_unix_members (&$at, $srv, $ldap, $name, $val) {
    $h_uids = array();
    $touched_uids = array();
    foreach (split_list($val) as $uidn) {
        if (! is_int($uidn)) {
            $h_uids[$uidn] = $touched_uids[$uidn] = 1;
            continue;
        }
        $entries = uldap_search($srv, "(&(objectClass=person)(uidNumber=$uidn))", array('uid'));
        $ue = $entries[0];
        $uid = isset($ue) ? nvl(uldap_value($ue, 'uid')) : '';
        log_debug('search for uidn="%d" returns uid="%s" (code=%s)', $uidn, $uid, $res['code']);
        if ($uid != '') {
            $h_uids[$uid] = $touched_uids[$uid] = 1;
        } else {
            log_info('did not find user uidn %s', $uidn);
        }
    }

	$a_uids = sort(array_keys($h_uids));
    log_debug('ldap_write_unix_members: uids(%s) [%s] => [%s]',
                $name, $val, join_list($a_uids));
    if (empty($a_uids)) {
        if (uldap_exists($ldap, $name)) {
            foreach (uldap_value($ldap, $name) as $x)
                $touched_uids[$x] = 1;
			uldap_delete($ldap, $name);
        }
    } else if (uldap_exists($ldap, $name)) {
        foreach (uldap_value($ldap, $name) as $x)
            $touched_uids{$x} = 1;
        uldap_replace($ldap, $name, $a_uids);
    } else {
        uldap_add($ldap, $name, $a_uids);
    }

    $sel_usr = $user_obj;
    if (!$sel_usr['changed'] && $touched_uids[get_attr($sel_usr, 'uid')]) {
        // will refresh gui for this user after commit to LDAP
        $sel_usr['refresh_request'] = 1;
        log_debug('will re-select current user');
    }

    return 1;
}


function ldap_write_unix_members_final (&$at, $srv, $ldap, $name, $val) {
    $sel_usr = $user_obj;
    if ($sel_usr['refresh_request']) {
        // refresh gui for this user
        log_debug('re-selecting user');
        $sel_usr['refresh_request'] = 0;
        user_load();
    }
    return 0;
}


//////////////////////////////////////////////////////////////
// POSIX passwd
//

function posix_read_real_uidn (&$at, $srv, $ldap, $name) {
    $username = nvl(uldap_value($ldap, 'uid'));
    $pwent = posix_getpwnam($username);
    return $pwent === FALSE ? '' : $pwent['uid'];
}


function posix_read_real_gidn (&$at, $srv, $ldap, $name) {
    $username = nvl(uldap_value($ldap, 'uid'));
    $pwent = posix_getpwnam($username);
    return $pwent === FALSE ? '' : $pwent['gid'];
}


?>
