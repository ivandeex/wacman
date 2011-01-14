<?php
// $Id$

// LDAP server interface

$servers = array(
    'uni' => array( 'disable' => 1 ),    // Unix LDAP Server
    'ads' => array( 'disable' => 1 ),    // Windows Active Directory
    'cgp' => array( 'disable' => 1 )     // CommuniGate Pro - CLI interface
);


///////////////////////////////////////////////
// Connections
//


function & get_server ($srv, $allow_disabled = false) {
    global $servers;
    if (! isset($servers[$srv]))
        error_page(_T('unknown ldap server "%s"', $srv));
    $cfg =& $servers[$srv];
    if (! $allow_disabled && $cfg['disable'])
        error_page(_T('server "%s" is disabled', $srv));
    return $cfg;
}


function uldap_connect ($srv) {
    global $servers;
    $cfg =& $servers[$srv];

    foreach (array('connected','failed','disable') as $prop)
        if (!isset($cfg[$prop]))  $cfg[$prop] = false;
    if (!isset($cfg['name']))  $cfg['name'] = $srv;
    if (!isset($cfg['ldap']))  $cfg['ldap'] = null;

    if ($cfg['connected'])
        return 0;
    if ($cfg['disable'] || $cfg['failed'])
        return -1;

    static $disconnect_registered;
    if (! $disconnect_registered) {
        $disconnect_registered = true;
        register_shutdown_function('_disconnect_all');
    }

    if ($srv == 'cgp')
        return cgp_connect($srv);

    $cfg['failed'] = true;
    if (empty($cfg['uri'])) {
        log_error('invalid uri for server "%s"', $srv);
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

    // Attempt to set LDAP protocol version 3.
    // Active directory requires this version.
    // Other servers might support it, let's try.
    // For renaming to work we need LDAP v3 everywhere.
    $okay = @ldap_set_option($cfg['ldap'], LDAP_OPT_PROTOCOL_VERSION, 3);
    if (! $okay) {
        log_error('cannot set protocol version 3 for server (%s): %s',
                    $srv, ldap_error($cfg['ldap']));
        return -1;
    }

    $okay = @ldap_bind($cfg['ldap'], $cfg['user'], $cfg['pass']);
    if (! $okay) {
        log_error('cannot bind to server "%s" (%s): %s',
                    $cfg['uri'], $srv, ldap_error($cfg['ldap']));
        return -1;
    }

    $cfg['connected'] = true;
    $cfg['failed'] = false;
    log_debug('connected to server "%s"', $srv);
    return 0;
}


function _uldap_connection ($srv, &$res) {
    $cfg =& get_server($srv, true);
    uldap_connect($srv);
    if (! $cfg['connected']) {
        $res['code'] = -1;
        $res['error'] = _T("%s: not connected", $srv);
        return null;
    }
    $res['code'] = 0;
    $res['error'] = '';
    return $cfg['ldap'];
}


function _disconnect_all () {
    global $servers;
    foreach ($servers as $srv => &$cfg) {
        if (isset($cfg['disable']) && $cfg['disable'])
            continue;
        if (!(isset($cfg['connected']) && $cfg['connected']))
            continue;
        #log_debug("disconnecting $srv");
        if ($srv == 'cgp') {
            cgp_disconnect($srv);
        } else {
            @ldap_close($cfg['ldap']);
        }
        unset($cfg['ldap']);
        $cfg['connected'] = false;
        $cfg['failed'] = false;
    }
}


///////////////////////////////////////////////
// Getting data
//


function _ldap_result ($okay, $conn, &$res) {
    if ($okay) {
        $res['code'] = 0;
        $res['error'] = '';
    } else {
        $res['code'] = ldap_errno($conn);
        $res['error'] = ldap_error($conn);
        $res['data'] = array();
    }
}


function _ldap_to_array (&$src, $in_root = false) {
    if (! is_array($src) || ! isset($src['count']))
        return $src;
    $got_named = false;
    foreach ($src as $key => $unused) {
        if (! is_int($key) && $key != 'count') {
            $got_named = true;
            break;
        }
    }
    if (!$in_root && $src['count'] == 1 && !$got_named)
        return _ldap_to_array($src[0]);
    $dst = array();
    foreach ($src as $key => &$val) {
        if ($key === 'count' || ($got_named && is_int($key)))
            continue;
        if ($got_named)
            $dst[$key] = _ldap_to_array($val);
        else
            $dst[] = _ldap_to_array($val);
    }
    return $dst;
}


function uldap_search ($srv, $filter, $attrs) {
    $res = array('data' => array());
    $conn = _uldap_connection($srv, $res);
    if (!$conn)  return $res;
    if (!$attrs)  $attrs = array('*');
    $cfg = get_server($srv);
    $handle = @ldap_search($conn, $cfg['base'], $filter, $attrs);
    if ($handle === false) {
        _ldap_result(false, $conn, $res);
        log_debug('uldap_search(%s,filter:[%s],attrs:[%s]) search failed: %s',
                    $srv, $filter, join_list($attrs), $res['error']);
        return $res;
    }
    $data = @ldap_get_entries($conn, $handle);
    if ($data === false) {
        _ldap_result(false, $conn, $res);
        log_debug('uldap_search(%s,filter:[%s],attrs:[%s]) entries failed: %s',
                    $srv, $filter, join_list($attrs), $res['error']);
        return $res;
    }
    _ldap_result(true, $conn, $res);
    $res['data'] = (array) _ldap_to_array($data, true);
    set_error();
    if ($cfg['debug'])
        log_debug('uldap_search(%s,filter:[%s]) OK: %s', $srv, $filter, json_encode($res['data']));
    return $res;
}


///////////////////////////////////////////////
// Manipulating data
//


function uldap_entries ($res) {
    return is_array($res['data']) ? $res['data'] : array();
}


function uldap_pop ($res) {
    return (array)(isset($res['data'][0]) ? $res['data'][0] : null);
}


function uldap_dn (&$data) {
    return (isset($data['dn']) ? $data['dn'] : '');
}


function uldap_set_dn (&$data, $dn = null) {
    $old_dn = uldap_dn($data);
    if ($dn)
        $ldap['dn'] = $dn;
    elseif (isset($data['dn']))
        unset($data['dn']);
    return $old_dn;
}


function dn_to_rdn ($dn) {
    // Remove comma which is not escaped by preceding backslash and the rest of string
    return preg_replace('/(?<!\\\\),.*$/', '', $dn);
}


function _fix_ldap_name(&$data, &$name) {
    if (isset($data[$name])) return $name;
    $lc = strtolower($name);
    if (isset($data[$lc]))  $name = $lc;
}


function uldap_value (&$data, $name, $want_array = false) {
    _fix_ldap_name($data, $name);
    $val = isset($data[$name]) ? $data[$name] : null;
    if ($want_array)  return (array)$val;
    return !is_array($val) ? $val : (isset($val[0]) ? $val[0] : null);
}


function uldap_exists (&$data, $name) {
    $val = uldap_value($data, $name);
    return !(is_null($val) || (is_array($val) && empty($val)));
}


function uldap_delete (&$data, $name) {
    _fix_ldap_name($data, $name);
    if (isset($data[$name]))
        unset($data[$name]);
}


function uldap_add (&$data, $name, $val) {
    _fix_ldap_name($data, $name);
    if (isset($data[$name])) {
        $data[$name] = array_merge((array)$data[$name], (array)$val);
        sort($data[$name]);
    } else {
        $data[$name] = $val;
    }
}


function uldap_replace (&$data, $name, $val) {
    _fix_ldap_name($data, $name);
    if (!isset($data[$name])) {
        $data[$name] = $val;
        return;
    }
    if (is_array($data[$name]))
        $data[$name] = (array)$val;
    else
        $data[$name] = is_array($val) ? join_list($val) : $val;
}


///////////////////////////////////////////////
// Modifying server entries directly
//


function uldap_entry_rename ($srv, $dn_old, $rdn_new) {
    $conn = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_rename($conn, $dn_old, $rdn_new, null, true), $conn, $res);
    return $res;
}


function uldap_entry_create ($srv, $dn, $values) {
    $conn = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_add($conn, $dn, $values), $conn, $res);
    return $res;
}


function uldap_entry_update ($srv, $dn, $values) {
    $conn = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_modify($conn, $dn, $values), $conn, $res);
    return $res;
}


function uldap_entry_delete ($srv, $dn) {
    $conn = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_delete($conn, $dn), $conn, $res);
    return $res;
}


function uldap_entry_add ($srv, $dn, $entry) {
    $conn = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_mod_add($conn, $dn, $entry), $conn, $res);
    return $res;
}


function uldap_entry_replace ($srv, $dn, $entry) {
    $conn = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_mod_replace($conn, $dn, $entry), $conn, $res);
    return $res;
}


//////////////////////////////////////////////////////////////
// Basic readers / Writers
//


function ldap_read_none () {
    return '';
}


function ldap_write_none () {
    return false;
}


function ldap_read_string (&$obj, &$at, $srv, &$ldap, $name) {
    return uldap_value($ldap, $name);
}


function ldap_write_string (&$obj, &$at, $srv, &$ldap, $name, $val) {
    $changed = false;
    if (empty($val)) {
		if (uldap_exists($ldap, $name)) {
			uldap_delete($ldap, $name);
			$changed = true;
			log_debug('ldap_write_string(%s): remove', $name);
		} else {
			#log_debug('ldap_write_string(%s): already removed', $name);
		}
	} else if (uldap_exists($ldap, $name)) {
		$old = nvl(uldap_value($ldap, $name));
		if ($val != $old) {
			uldap_replace($ldap, $name, $val);
			$changed = true;
			log_debug('ldap_write_string(%s): "%s" -> "%s"', $name, $old, $val);
		} else {
			#log_debug('ldap_write_string(%s): preserve "%s"', $attr, $val);			
		}
	} else {
		uldap_add($ldap, $name, $val);
		$changed = true;
		log_debug('ldap_write_string(%s): add "%s"', $name, $val);			
	}
	return $changed;
}


function ldap_read_dn (&$obj, &$at, $srv, &$ldap, $name) {
	return uldap_dn($ldap);
}


function ldap_write_dn (&$obj, &$at, $srv, &$ldap, $name, $val) {
    $prev = nvl(uldap_dn($ldap));
    $val = nvl($val);
    log_debug('ldap_write_dn(%s): attr="%s" dn="%s", prev="%s"',
                $srv, $at['name'], $val, $prev);
    if ($val == $prev || $val == '')
        return false;
    uldap_set_dn($ldap, $val);
    return true;
}


function ldap_read_class (&$obj, &$at, $srv, &$ldap, $name) {
    return join_list(uldap_value($ldap, $name, true));
}


function ldap_write_class (&$obj, &$at, $srv, &$ldap, $name, $val) {
    $changed = false;
    $ca = array();
    foreach (uldap_value($ldap, $name, true) as $c)
        $ca[strtolower($c)] = 1;
    foreach (split_list($val) as $c) {
        if (isset($ca[strtolower($c)]))
            continue;
        uldap_add($ldap, $name, $c);
        $changed = true;
    }
    log_debug('ldap_write_class(%s): attr="%s" class="%s" dn="%s" changed=%d',
                $srv, $at['name'], $val, get_attr($obj, 'dn'), $changed);
    return $changed;
}


function ldap_read_pass (&$obj, &$at, $srv, &$ldap, $name) {
    global $servers;
    $val = '';
    if (! get_config('show_password') || $servers['cgp']['disable']) {
        $val = OLD_PASS;
    } else if ($srv == 'cgp') {
        $val = ldap_read_string($at, $srv, $ldap, $name);
    }
    return( $at['oldpass'] = nvl($val) );
}


function ldap_write_pass (&$obj, &$at, $srv, &$ldap, $name, $val) {
    if ($at['desc']['verify'] || $val == nvl($at['oldpass']))
        return false;
    if ($srv == 'ads') {
        // 'replace' works only for administrator.
        // unprivileged users need to use change(delete=old,add=new)
        uldap_replace($ldap, $name, encode_ad_pass($val));
        return true;
    }
    return false;
}


function ldap_write_pass_final (&$obj, &$at, $srv, &$ldap, $name, $val) {
    if ($at['desc']['verify'] || $val == nvl($at['oldpass']))
        return false;
    if ($srv == 'uni')
        return unix_write_pass_final($at, $srv, $ldap, $name, $val);
    if ($srv == 'cgp')
        return cgp_write_pass_final($at, $srv, $ldap, $name, $val);
    return false;
}


?>
