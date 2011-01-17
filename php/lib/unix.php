<?php
// $Id$


//////////////////////////////////////////////////////////////
// Unix LDAP for users
//


function unix_read_gidn (&$obj, &$at, $srv, &$data, $name) {
    $srv = 'uni';
    $val = uldap_value($data, $name);
	if (! preg_match('/^\d+$/', $val))
	    return $val; // it's a group name

    // it's a numeric identifier. looking for a group.
    $res = uldap_search($srv, "(&(objectClass=posixGroup)(gidNumber=$val))", array('cn'));
    $cn = uldap_value(uldap_pop($res), 'cn');
    if (empty($cn)) {
        log_error('unix_read_gidn(%s): cannot find group: %s', $val, $res['error']);
        return $val;
    }

    log_debug('unix_read_gidn(%s): OK name="%s"', $val, $cn);
    return $cn;
}


function unix_write_gidn (&$obj, &$at, $srv, &$data, $name, $val) {
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


function unix_read_user_groups (&$obj, &$at, $srv, &$data, $name) {
    $uid = $obj['id'];
    if (empty($uid))  return '';

    $res = uldap_search($srv, "(&(objectClass=posixGroup)(memberUid=$uid))", array('cn'));

    $val = array();
    foreach (uldap_entries($res) as $ge)  $val[] = uldap_value($ge, 'cn');

    // cache the value for use by unix_write_user_groups_final()
    $at['old'] = $val = join_list($val);
    return $val;
}


function unix_write_user_groups_final (&$obj, &$at, $srv, &$data, $name, $val) {
    $uid = $obj['id'];
    if (empty($uid))  return '';

    // get previous and current lists of groups
    $old = isset($at['old']) ? $at['old'] : '';
    $old = _get_unix_group_ids($obj, $srv, $old, false);
    $new = _get_unix_group_ids($obj, $srv, $val, true);
    log_debug('write_unix_groups(1): old=(%s) new=(%s)', json_encode($old), json_encode($new));

    // find groups to delete user from and to add user to
    list($del, $add, $unchanged) = compare_lists($old, $new);
    log_debug('write_unix_groups(2): del=(%s) add=(%s)', json_encode($del), json_encode($add));

    // perform the modifications
    foreach (split_list($del) as $gidn)
        _modify_unix_group($obj, $srv, $gidn, $uid, false);
    foreach (split_list($add) as $gidn)
        _modify_unix_group($obj, $srv, $gidn, $uid, true);

    return !(empty($del) && empty($add));
}


function _get_unix_group_ids (&$obj, $srv, $val, $warn = false) {
    $arr_ids = split_list($val);
    if (empty($arr_ids))  return array();

    // we keep track of handled ids here
    $left_ids = array();
    foreach ($arr_ids as $x)  $left_ids[$x] = 1;

    $or_conds = array();
    foreach ($arr_ids as $x) {
        // if number, it is probably gidNumber but we try group name as well
        // otherwise, it can be a group name only.
        $or_conds[] = preg_match('/^\d+$/', $x) ? "(cn=$x)(gidNumber=$x)" : "(cn=$x)";
    }
    $or_conds = implode('', $or_conds);

    // perform the search
    $filter = "(&(objectClass=posixGroup)(|$or_conds))";
    log_debug('request for "%s" is "%s"', $val, $filter);
    $res = uldap_search($srv, $filter, array('cn', 'gidNumber'));

    // retrieve numeric groups identifiers
    $gidns = array();
    foreach (uldap_entries($res) as $grp) {
        $gidn = uldap_value($grp, 'gidNumber');
        $cn = uldap_value($grp, 'cn');
        $gidns[] = $gidn;
        // keep track of successfully found ids
        unset($left_ids[$gidn]);
        unset($left_ids[$cn]);
    }

    // warn user about unfound groups
    if ($warn && !empty($left_ids))
        $obj['msg'][] = log_error('groups not found: %s', join_list(array_keys($left_ids)));

    // return the list
    sort($gidns);
    log_debug('group ids for "%s" is "%s"', $val, join_list($gidns));
    return $gidns;
}


function _modify_unix_group (&$obj, $srv, $gidn, $uid, $add) {
    $action = $add ? 'add' : 'remove';
    log_debug('modify_unix_group(%s,%s,%s): begin', $gidn, $action, $uid);

    // obtain the group DN and member user ids
    $res = uldap_search($srv, "(&(objectClass=posixGroup)(gidNumber=$gidn))", array('memberUid'));
    $grp = uldap_pop($res);
    if (empty($grp)) {
        $obj['msg'][] = log_error('cannot find unix group %s for modification: %s',
                                    $gidn, $res['error']);
        return $res['error'];
    }

    $old = uldap_value($grp, 'memberUid', true);
    $old = empty($old) ? '' : join_list($old);
    $new = join_list($add ? append_list($old, $uid) : remove_list($old, $uid));

    if ($old == $new) {
        log_debug('modify_unix_group(%s,%s,%s): no change (%s)',
                    $gidn, $action, $uid, $old);
        return false;
    }

    $new_uids = array('memberUid' => split_list($new));
    $res = uldap_entry_update($srv, uldap_dn($grp), $new_uids);
    if ($res['code']) {
        $obj['msg'][] = log_error('modify_unix_group(%s,%s,%s) error: %s',
                                    $gidn, $action, $uid, $res['error']);
        return $res['error'];
    }

    log_debug('modify_unix_group(%s,%s,%s): OK [%s] -> [%s]',
                $gidn, $action, $uid, $old, $new);
    return '';
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


//////////////////////////////////////////////////////////////
// Unix LDAP for groups
//


function unix_read_group_members (&$obj, &$at, $srv, &$data, $name) {
    // RHDS returns uid numbers, OpenLDAP returns usernames. We handle both cases.
    $uidns = uldap_value($data, $name, true);
    log_debug('unix_read_group_members(%s): uidns=(%s)', $name, join_list($uidns));
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
    log_debug('unix_read_group_members(%s): result=(%s)', $name, $val);
    return $val;
}


function unix_write_group_members (&$obj, &$at, $srv, &$data, $name, $val) {
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

    log_debug('unix_write_group_members: uids(%s) [%s] => [%s]', $name, $val, join_list($uid_arr));
    return true;
}


//////////////////////////////////////////////////////////////
// POSIX passwd
//

function posix_read_real_uidn (&$obj, &$at, $srv, &$data, $name) {
    $username = nvl(uldap_value($data, 'uid'));
    $pwent = posix_getpwnam($username);
    return $pwent === false ? '' : $pwent['uid'];
}


function posix_read_real_gidn (&$obj, &$at, $srv, &$data, $name) {
    $username = nvl(uldap_value($data, 'uid'));
    $pwent = posix_getpwnam($username);
    return $pwent === false ? '' : $pwent['gid'];
}


?>
