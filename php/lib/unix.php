<?php
// $Id$


//////////////////////////////////////////////////////////////
// Unix OpenLDAP
//

function ldap_read_unix_gidn (&$obj, &$at, $srv, &$data, $name) {
    $srv = 'uni';
    $val = nvl(uldap_value($data, $at['name']));
	if (! preg_match('/^\d+$/', $val))
	    return $val;
    $res = uldap_search($srv, "(&(objectClass=posixGroup)(gidNumber=$val))", array('cn'));
    if (empty($res['data'])) {
        log_debug('ldap_read_unix_gidn(): cannot find group id=%s (error: %s)',
                    $val, $res['error']);
        return $val;
    }
    $cn = uldap_value(uldap_pop($res), 'cn');
    if (empty($cn))
        return $val;
    log_debug('ldap_read_unix_gidn(): found group id=%s name=%s', $val, $cn);
    return $cn;
}


function ldap_write_unix_gidn (&$obj, &$at, $srv, &$data, $name, $val) {
    $srv = 'uni';
    if (!empty($val) && !preg_match('/^\d+$/', $val)) { // /^\d*$/
        $cn = $val;
        $val = 0;
        $res = uldap_search($srv, "(&(objectClass=posixGroup)(cn=$cn))", array('gidNumber'));
        $grp = uldap_pop($res);
        if (!empty($grp)) {
            $gidn = uldap_value($grp, 'gidNumber');
            if ($gidn)  $val = $gidn;
        }
        if (!$val)  log_info('ldap_write_gidn: group "%s" not found on %s', $cn, $srv);
    }
    log_debug('ldap_write_unix_gidn: set group to "%s"', $val);
    return ldap_write_string($obj, $at, $srv, $data, $name, $val);
}


function unix_write_pass_final (&$obj, &$at, $srv, &$data, $name, $val) {
    global $servers;
    $conf =& $servers[$srv];
    if (! isset($conf['extop'])) {
        $conf['extop'] = false; # FIXME $data->root_dse->supported_extension('1.3.6.1.4.1.4203.1.11.1');
    }
    $extop = $conf['extop'];
    $dn = get_attr($obj, 'dn');
    if ($extop) {
        // set_password() without 'oldpasswd' works only for administrator
        // ordinary users need to supply 'oldpasswd'
        #$res = $conf['conn']->set_password(user => $dn, newpasswd => $val);
    } else {
        // 'replace' works only for administrator.
        // unprivileged users need to use change(delete=old,add=new)
        $res = uldap_modify($data, $dn, $name, $val);
    }
    log_debug('change password on "%s": dn="%s" extop=%d attr=%s code=%d',
                $srv, $dn, $extop, $name, $res['code']);
    if ($res['code']) {
        message_box('error', 'close',
                    _T('Cannot change password for "%s" on "%s": %s',
                        $dn, $srv, $res['error']));
        return false;
    }
    return true;
}


function ldap_read_unix_groups (&$obj, &$at, $srv, &$data, $name) {
    $uid = nvl(uldap_value($data, $name));
    if (!isset($uid) || !$uid)
        $uid = get_attr($obj, $name);
    $res = uldap_search($srv, "(&(objectClass=posixGroup)(memberUid=$uid))", array('cn'));
    $arr = array();
    foreach (uldap_entries($res) as $e)
        $arr[] = uldap_value($e, 'cn');
    return join_list($arr);
}


function _get_unix_group_ids ($srv, $val, $warn, $asstring = false) {
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


function modify_unix_group ($srv, $gidn, $uid, $action) {
    log_debug('will %s unix user "%s" in group %d...',  $action, $uid, $gidn);
    $srv = 'uni';
    $res = uldap_search($srv, "(&(objectClass=posixGroup)(gidNumber=$gidn))", array('memberUid'));
    $grp = uldap_pop($res);
    if ($res['code'] || empty($grp)) {
        log_info('cannot find unix group %d for modification', $gidn);
        return $res['error'];
    }

    $old_uids = uldap_value($grp, 'memberUid', true);
    $exists = !empty($old_uids);
    $old = $exists ? join_list($old_uids) : '';
    $new = join_list($action == 'add' ? append_list($old, $uid) : remove_list($old, $uid));
    if ($old == $new) {
        log_debug('unix group %d wont change with user "%s": (%s) = (%s)',
                    $gidn, $uid, $old, $new);
        return 'SAME';
    }

    $grp_dn = uldap_dn($grp);
    $new_uids = array('memberUid' => split_list($new));
    if ($exists)
        $res = uldap_entry_replace($srv, $grp_dn, $new_uids);
    else
        $res = uldap_entry_add($srv, $grp_dn, $new_uids);
    if ($res['code']) {
        log_info('%s unix user "%s" in group %d error: %s',
                    $action, $uid, $gidn, $res['error']);
        return $res['error'];
    }
    log_debug('successful %s unix user "%s" in group %d: [%s] -> [%s]...',
                $action, $uid, $gidn, $old, $new);
    return 'OK';
}


function ldap_write_unix_groups_final (&$obj, &$at, $srv, &$data, $name, $val) {
return false; #FIXME
    $uid = get_attr($obj, $name);
    $old = _get_unix_group_ids($srv, $at['old'], 'nowarn'); # FIXME!!!
    $new = _get_unix_group_ids($srv, $at['val'], 'warn');
    log_debug('write_unix_groups(1): old=(%s) new=(%s)', $old, $new);
    $arr = compare_lists($old, $new);
    $old = $arr[0];
    $new = $arr[1];
    log_debug('write_unix_groups(2): del=(%s) add=(%s)', $old, $new);
    foreach (split_list($old) as $gidn)
        modify_unix_group($srv, $gidn, $uid, 'remove');
    foreach (split_list($new) as $gidn)
        modify_unix_group($srv, $gidn, $uid, 'add');
    return ($old != '' || $new != '');
}


function ldap_read_unix_members (&$obj, &$at, $srv, &$data, $name) {
    // RHDS returns uid numbers, OpenLDAP returns usernames. We handle both cases.
    $uidns = uldap_value($data, $name, true);
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


function ldap_write_unix_members (&$obj, &$at, $srv, &$data, $name, $val) {
    $uid_hash = array();

    foreach (split_list($val) as $uidn) {
        if (! preg_match('/^\d+$/', $uidn)) {
            $uid_hash[$uidn] = 1;
            continue;
        }
        $res = uldap_search($srv, "(&(objectClass=person)(uidNumber=$uidn))", array('uid'));
        $uid = nvl(uldap_value(uldap_pop($res), 'uid'));
        if ($uid != '') {
            log_debug('search for uidn="%d" returns uid="%s"', $uidn, $uid);
            $uid_hash[$uid] = 1;
        } else {
            log_info('cannot find user for id %s: %s', $uidn, $res['error']);
        }
    }

    $uid_arr = array_keys($uid_hash);
    sort($uid_arr);

    if (empty($uid_arr)) {
        uldap_delete($data, $name);
    } else if (uldap_exists($data, $name)) {
        uldap_replace($data, $name, $uid_arr);
    } else {
        uldap_add($data, $name, $uid_arr);
    }

    log_debug('ldap_write_unix_members: uids(%s) [%s] => [%s]', $name, $val, join_list($uid_arr));
    return true;
}


//////////////////////////////////////////////////////////////
// POSIX passwd
//

function posix_read_real_uidn (&$obj, &$at, $srv, &$data, $name) {
    $username = nvl(uldap_value($data, 'uid'));
    $pwent = posix_getpwnam($username);
    return $pwent === FALSE ? '' : $pwent['uid'];
}


function posix_read_real_gidn (&$obj, &$at, $srv, &$data, $name) {
    $username = nvl(uldap_value($data, 'uid'));
    $pwent = posix_getpwnam($username);
    return $pwent === FALSE ? '' : $pwent['gid'];
}


?>
