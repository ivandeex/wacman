<?php
// $Id$

// LDAP server interface

$servers = array(
    'uni' => array( 'disable' => 1 ),    // Unix LDAP Server
    'ads' => array( 'disable' => 1 ),    // Windows Active Directory
    'cgp' => array( 'disable' => 1 ),    // CommuniGate Pro
    'cli' => array( 'disable' => 1 )     // CommuniGate Pro - CLI interface
);


function get_server_names () {
    global $servers;
    return array_keys($servers);
}


function & get_server ($srv, $allow_disabled = false) {
    global $servers;
    if (! isset($servers[$srv]))
        error_page(_T('unknown ldap server "%s"', $srv));
    $cfg = &$servers[$srv];
    if (! $allow_disabled && $cfg['disable'])
        error_page(_T('server "%s" is disabled', $srv));
    return $cfg;
}


function uldap_connect ($srv) {
    global $servers;
    $cfg = &$servers[$srv];
    $cfg['name'] = $srv;
    $cfg['connected'] = 0;
    if ($srv == 'cli')
        return cli_connect();
    if ($cfg['disable']) {
        $cfg['ldap'] = null;
        return 0;
    }
    if (empty($cfg['uri'])) {
        log_error('invalid uri for server "%s"', $srv);
        $cfg['ldap'] = null;
        return -1;
    }
    $creds = get_credentials($srv);
    $cfg['user'] = $creds['user'];
    $cfg['pass'] = $creds['pass'];
    $cfg['ldap'] = @ldap_connect($cfg['uri']);
    if (! $cfg['ldap']) {
        log_error('error binding to server "%s"', $srv);
        return -1;
    }
    log_debug('connecting to server "%s"...', $srv);
    $okay = @ldap_bind($cfg['ldap'], $cfg['user'], $cfg['pass']);
    if (! $okay) {
        log_error('cannot bind to server "%s" (%s): %s',
                    $cfg['uri'], $srv, ldap_error($cfg['ldap']));
        return -1;
    }
    $cfg['connected'] = 1;
    log_debug('successfully connected to server "%s"', $srv);
    return 0;
}


function uldap_connect_all () {
    global $servers;
    foreach ($servers as $srv => $cfg) {
        log_info('connecting to "%s"', $srv);
        $cfg['connected'] = 0;
        if (uldap_connect($srv) < 0)
            log_error('connection to "%s" failed', $srv);
    }
}


function uldap_disconnect_all () {
    global $servers;
    foreach ($servers as $srv => &$cfg) {
        if ($cfg['disable'] || ! $cfg['connected'])
            continue;
        if ($cfg['name'] == 'cli')
            cli_disconnect();
        else
            ldap_close($cfg['ldap']);
        unset($cfg['ldap']);
        $cfg['connected'] = 0;
    }
}


function uldap_convert_array (&$src) {
    if (! is_array($src) || ! isset($src['count']))
        return $src;
    $got_named = false;
    foreach (array_keys($src) as $key) {
        if (! is_int($key) && $key != 'count') {
            $got_named = true;
            break;
        }
    }
    if ($src['count'] == 1 && ! $got_named)
        return uldap_convert_array($src[0]);
    $dst = array();
    foreach ($src as $key => &$val) {
        if ($key === 'count' || ($got_named && is_int($key)))
            continue;
        if ($got_named)
            $dst[$key] = uldap_convert_array($val);
        else
            $dst[] = uldap_convert_array($val);
    }
    return $dst;
}


function uldap_value ($data, $name, $asarray = false) {
    $src = $data;
    if (is_array($src) && isset($src['count']) && $src['count'] == 1 && is_array($src[0]))
        $src = $src[0];
    $lcname = strtolower($name);
    if (isset($src[$lcname]))
        $val = $src[$lcname];
    else if (isset($src[$name]))
        $val = $src[$name];
    else
        $val = array();
    unset($val['count']);
    if (is_array($val) && !$asarray) {
        if (count($val) == 1)
            $val = $val[0];
        else if (count($val) == 0)
            $val = null;
    }
    #echo _T("ugv(%s,%s):(%s)======>(%s)<br>\n", $name, $asarray?"T":"F", print_r($data,1), print_r($val,1));
    return $val;
}

function uldap_entries ($res) {
    $entries = array();
    if (isset($res['data']['count'])) {
        $count = $res['data']['count']; // this is how php ldap works
    } elseif (isset($res['data'][0])) {
        $count = count($res['data']); // this is how cli works
    } else {
        $count = 0;
    }
    for ($i = 0; $i < $count; $i++)
        $entries[] = $res['data'][$i];
    return $entries;
}

function uldap_dn (&$ldap) {
    return isset($ldap[0]['dn']) ? $ldap[0]['dn'] : null;
}

function uldap_json_encode ($res) {
    if ($res['code'])
        return json_error($res['error']);
    return "{success:true,rows:" . json_encode(uldap_convert_array($res['data'])) . "}\n";
}


function uldap_search ($srv, $filter, $attrs = null, $params = null)
{
    $cfg = &get_server($srv, true);
    if (! $cfg['connected'])
        return array('code' => -1, 'error' => 'not connected', 'data' => array('count' => 0));
    $conn = $cfg['ldap'];
    $handle = @ldap_search($conn, $cfg['base'], $filter, $attrs);
    if ($handle === FALSE)
        return array('code' => ldap_errno($conn), 'error' => ldap_error($conn), 'data' => array('count' => 0));
    $res = array();
    $res['data'] = @ldap_get_entries($conn, $handle);
    if ($res['data'] === FALSE) {
        $res['code'] = ldap_errno($conn);
        $res['error'] = ldap_error($conn);
        $res['data'] = array('count' => 0);
        log_error('ldap_search for "%s" on "%s" failed: %s', $filter, $srv, $res['code']);
        return $res;
    }
    $res['code'] = 0;
    $res['error'] = '';
    set_error();
    return $res;
}


//////////////////////////////////////////////////////////////
// ================  ldap readers / writers  ================
//


function ldap_read_none () {
    return '';
}


function ldap_write_none () {
    return 0;
}


function ldap_read_string (&$at, $srv, $ldap, $name) {
    return nvl(uldap_value($ldap, $name));
}


function ldap_write_string (&$at, $srv, $ldap, $name, $val) {
    $changed = 0;
    if ($val == '') {
		if (uldap_exists($ldap, $name)) {
			uldap_delete($ldap, $name);
			$changed = 1;
			log_debug('ldap_write_string(%s): remove', $name);
		} else {
			#log_debug('ldap_write_string(%s): already removed', $name);
		}
	} else if (uldap_exists($ldap, $name)) {
		$old = nvl(uldap_value($ldap, $name));
		if ($val != $old) {
			uldap_replace($ldap, $name, $val);
			$changed = 1;
			log_debug('ldap_write_string(%s): "%s" -> "%s"', $name, $old, $val);
		} else {
			#log_debug('ldap_write_string(%s): preserve "%s"', $attr, $val);			
		}
	} else {
		uldap_add($ldap, $name, $val);
		$changed = 1;
		log_debug('ldap_write_string(%s): add "%s"', $name, $val);			
	}
	return $changed;
}


function ldap_read_dn (&$at, $srv, $ldap, $name) {
	return nvl(uldap_dn($ldap));
}


function ldap_write_dn (&$at, $srv, $ldap, $name, $val) {
    $prev = nvl(uldap_dn($ldap));
    $val = nvl($val);
    log_debug('ldap_write_dn(%s): attr="%s" dn="%s", prev="%s"',
                $srv, $at['name'], $val, $prev);
    if ($val == $prev || $val == '')
        return 0;
    uldap_set_dn($ldap, $val);
    return 1;
}


function ldap_read_class (&$at, $srv, $ldap, $name) {
    return join_list(uldap_value($ldap, $name));
}


function ldap_write_class (&$at, $srv, $ldap, $name, $val) {
    $changed = 0;
    $ca = array();
    foreach (uldap_value($ldap, $name) as $c)
        $ca[strtolower($c)] = 1;
    foreach (split_list($val) as $c) {
        if (isset($ca[strtolower($c)]))
            continue;
        uldap_add($ldap, $name, $c);
        $changed = 1;
    }
    log_debug('ldap_write_class(%s): attr="%s" class="%s" changed=%d',
                $srv, $at['name'], $val, $changed);
    return $changed;
}


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


function ldap_read_real_uidn (&$at, $srv, $ldap, $name) {
    $username = nvl(uldap_value($ldap, 'uid'));
    $pwent = posix_getpwnam($username);
    return $pwent === FALSE ? '' : $pwent['uid'];
}


function ldap_read_real_gidn (&$at, $srv, $ldap, $name) {
    $username = nvl(uldap_value($ldap, 'uid'));
    $pwent = posix_getpwnam($username);
    return $pwent === FALSE ? '' : $pwent['gid'];
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


function ldap_read_pass (&$at, $srv, $ldap, $name) {
    global $servers;
    $val = '';
    if (! get_config('show_password') || $servers['cgp']['disable']) {
        $val = OLD_PASS;
    } else if ($srv == 'cgp') {
        $val = ldap_read_string($at, $srv, $ldap, $name);
    }
    return( $at['oldpass'] = nvl($val) );
}


function ldap_write_pass (&$at, $srv, $ldap, $name, $val) {
    if ($at['desc']['verify'] || $val == nvl($at['oldpass']))
        return 0;
    if ($srv == 'ads') {
        // 'replace' works only for administrator.
        // unprivileged users need to use change(delete=old,add=new)
        uldap_replace($ldap, $name, encode_ad_pass($val));
        return 1;
    }
    return 0;
}


function ldap_write_pass_final (&$at, $srv, $ldap, $name, $val) {
    if ($at['desc']['verify'] || $val == nvl($at['oldpass']))
        return 0;
    global $servers;
    if ($srv == 'uni') {
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
    if ($srv == 'cgp') {
        $ldap =& $servers[$srv]['ldap'];
        $obj =& $at['obj'];
        $dn = get_attr($obj, 'cgpDn');

        $alg = get_config('cgp_password');
        $cgpass = nvl($val);
        if (preg_match('/^\{\w{2,5}\}\w+$/', $cgpass) && get_config('show_password')) {
            $cgpass = "\x2" . $cgpass;
            if ($alg != 'cli')
                $alg = 'clear';
        }
        if ($alg == 'cli') {
			$mail = get_attr($obj, 'mail');
			$passenc = nvl(get_config('cgp_pass_encryption'));
            if ($passenc != '') {
                $res = cli_cmd('UpdateAccountSettings %s { UseAppPassword = YES; }',
                                $mail, $passenc);
				if ($res['code'])
				    log_info('Cannot enable CGP passwords for %s: %s',
                            $mail, $res['msg']);
                $res = cli_cmd('UpdateAccountSettings %s { PasswordEncryption = %s; }',
                                $mail, $passenc);
                if ($res['code'])
                    log_info('Cannot change encryption for %s to %s: %s',
                            $mail, $passenc, $res['msg']);
                if (get_config('debug'))
                    $res = cli_cmd('GetAccountEffectiveSettings %s', $mail);
			}
            $res = cli_cmd('SetAccountPassword %s PASSWORD %s', $mail, $cgpass);
            if (! $res['code'])
                return 1;
            message_box('error', 'close',
                        _T('Cannot change password for "%s" on "%s": %s',
                            $mail, $srv, $res->{msg}));
            return 0;
        } 
        if ($alg == 'sha') {
            $cgpass = "\x2{SHA}" . base64_encode(sha1($val, true));
        } else {
            $cgpass = nvl($val);
        }
        log_debug('cgpass=%s', $cgpass);

        // 'replace' works only for administrator.
        // unprivileged users need to use change(delete=old,add=new)
        $res = uldap_modify($ldap, $dn, $name, $cgpass);
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


function ldap_read_aliases (&$at, $srv, $ldap, $name) {
    $dn = nvl(uldap_dn($ldap));
    if ($dn == '')
        return '';
    $aliases = array();
    $telnum = '';
    $old_telnum = get_attr($at['obj'], 'telnum', array('orig' => 1));
    $entries = uldap_search($srv, "(&(objectClass=alias)(aliasedObjectName=$dn))", array('uid'));
    foreach ($entries as $e) {
        $alias = uldap_value($e, 'uid');
        if ($old_telnum == '' && $telnum == '' && preg_match('/^\d{3}$/', $alias)) {
			$telnum = $alias;
        } else {
            $aliases[] = $alias;
        }
    }
    $aliases = join_list($aliases);
    log_debug('read aliases: telnum="%s" aliases="%s"', $telnum, $aliases);
    if ($telnum != '')
        init_attr($at['obj'], 'telnum', $telnum);
    return $aliases;
}


function ldap_write_aliases_final (&$at, $srv, $ldap, $name, $val) {
    $obj =& $at['obj'];
    $old = append_list(nvl($at['old']), get_attr($obj, 'telnum', array('orig' => 1))); # FIXME!!!
    $new = append_list(nvl($at['val']), get_attr($obj, 'telnum'));
    log_debug('write_aliases_final: old="%s" new="%s"', $old, $new);
    if ($old == $new)
        return 0;
    if (get_config('cgp_buggy_ldap')) {
        $mail = get_attr($obj, 'mail');
        $res = cli_cmd('SetAccountAliases %s (%s)', $mail, join_list(split_list($new)));
        log_debug('set_mail_aliases: code="%s" msg="%s" out="%s"',
                    $res['code'], $res['msg'], $res['out']);
        if ($res['code'] == 0)
            return 1;
        message_box('error', 'close',
                    _T('Cannot change mail aliases for "%s": %s', $mail, $res['msg']));
        return 0;
    } else {
        $aliased = get_attr($obj, 'cgpDn');
        log_debug('write_aliases(1): old=(%s) new=(%s)', $old, $new);
        $arr = compare_lists($old, $new);
        $old = $arr[0];
        $new = $arr[1];
        log_debug('write_aliases(2): del=(%s) add=(%s)', $old, $new);
        foreach (split_list($old) as $aid) {
            $dn = get_obj_config($obj, 'cgp_user_dn', array('uid' => $aid));
            $res = uldap_delete($srv, $dn);
            log_debug('Removing mail alias "%s" for "%s": %s', $dn, $aliased, $res['error']);
        }
        foreach (split_list($new) as $aid) {
            $dn = get_obj_config($obj, 'cgp_user_dn', array('uid' => $aid));
            log_debug('Adding mail alias "%s" for "%s": %s', $dn, $aliased, 'unimplemented');
        }
        return ($old != '' || $new != '');
    }
}


function ldap_read_mail_groups (&$at, $srv, $ldap, $name) {
    $uid = nvl(uldap_value($ldap, 'uid'));
    if ($uid == '')
        return '';
    $entries = uldap_search($srv, "(&(objectClass=CommuniGateGroup)(groupMember=$uid))", array('uid'));
    $arr = array();
    foreach ($entries as $ue)
        $arr[] = uldap_value($ue, 'uid');
    return join_list($arr);
}


?>
