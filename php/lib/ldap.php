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
    if (!isset($cfg['conn']))  $cfg['conn'] = null;

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
    $cfg['conn'] = @ldap_connect($cfg['uri']);
    if (! $cfg['conn']) {
        log_error('error binding to server "%s"', $srv);
        return -1;
    }

    // StartTLS
    if (str2bool(@$cfg['start_tls'])) {
        $ok = @ldap_start_tls($cfg['conn']);
        if (!$ok) {
            log_error('cannot start tls for server (%s): %s',
                    $srv, ldap_error($cfg['conn']));
            return -1;
        }
    }

    // Attempt to set LDAP protocol version 3.
    // Active directory requires this version.
    // Other servers might support it, let's try.
    // For renaming to work we need LDAP v3 everywhere.
    $ok = @ldap_set_option($cfg['conn'], LDAP_OPT_PROTOCOL_VERSION, 3);
    if (!$ok) {
        log_error('cannot set protocol version 3 for server (%s): %s',
                    $srv, ldap_error($cfg['conn']));
        return -1;
    }

    $ok = @ldap_bind($cfg['conn'], $cfg['user'], $cfg['pass']);
    if (!$ok) {
        log_error('cannot bind to server "%s" (%s): %s',
                    $cfg['uri'], $srv, ldap_error($cfg['conn']));
        return -1;
    }

    $cfg['connected'] = true;
    $cfg['failed'] = false;

    if ($cfg['debug'])
        log_debug('connected to server "%s"', $srv);
    return 0;
}


function _uldap_connection ($srv, &$res) {
    $cfg =& get_server($srv, true);
    uldap_connect($srv);
    if (! $cfg['connected']) {
        $res['code'] = -1;
        $res['error'] = _T("%s: not connected", $srv);
        return array(null, false);
    }
    $res['code'] = 0;
    $res['error'] = '';
    return array($cfg['conn'], $cfg['debug']);
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
            @ldap_unbind($cfg['conn']);
        }
        $cfg['conn'] = null;
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
    list($conn, $debug) = _uldap_connection($srv, $res);
    if (!$conn)  return $res;
    if (!$attrs)  $attrs = array('*');
    $cfg = get_server($srv);
    $handle = @ldap_search($conn, $cfg['base'], $filter, $attrs);
    if ($handle === false) {
        _ldap_result(false, $conn, $res);
        if ($debug)
            log_info('uldap_search(%s,filter:[%s],attrs:[%s]) search failed: %s',
                    $srv, $filter, join_list($attrs), $res['error']);
        return $res;
    }
    $data = @ldap_get_entries($conn, $handle);
    if ($data === false) {
        _ldap_result(false, $conn, $res);
        if ($debug)
            log_info('uldap_search(%s,filter:[%s],attrs:[%s]) entries failed: %s',
                    $srv, $filter, join_list($attrs), $res['error']);
        return $res;
    }
    _ldap_result(true, $conn, $res);
    $res['data'] = (array) _ldap_to_array($data, true);
    if (empty($res['data']))
        $res['error'] = "No data";
    set_error();
    if ($debug)
        log_info('uldap_search(%s,filter:[%s],attrs:[%s]) OK: %s',
                $srv, $filter, /*join_list($attrs)*/ '...', json_encode($res['data']));
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
        $data['dn'] = $dn;
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
    list($conn, $debug) = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_rename($conn, $dn_old, $rdn_new, null, true), $conn, $res);
    if ($debug)
        log_info('uldap_entry_rename(%s) [%s] => [%s]: %s',
                    $srv, $dn_old, $rdn_new, json_encode($res));
    return $res;
}


function uldap_entry_create ($srv, $dn, $data) {
    list($conn, $debug) = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_add($conn, $dn, $data), $conn, $res);
    if ($debug)
        log_info('uldap_entry_create(%s) [%s] => [%s]: %s',
                    $srv, $dn, json_encode($data), json_encode($res));
    return $res;
}


function uldap_entry_update ($srv, $dn, $data) {
    list($conn, $debug) = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_modify($conn, $dn, $data), $conn, $res);
    if ($debug)
        log_info('uldap_entry_update(%s) [%s] => [%s]: %s',
                    $srv, $dn, json_encode($data), json_encode($res));
    return $res;
}


function uldap_entry_delete ($srv, $dn) {
    list($conn, $debug) = _uldap_connection($srv, $res);
    if ($conn)
        _ldap_result(@ldap_delete($conn, $dn), $conn, $res);
    if ($debug)
        log_info('uldap_entry_delete(%s) [%s]: %s', $srv, $dn, json_encode($res));
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


function ldap_read_string (&$obj, &$at, $srv, &$data, $name) {
    return uldap_value($data, $name);
}


function ldap_write_string (&$obj, &$at, $srv, &$data, $name, $val) {
    $changed = false;
    if (empty($val)) {
        if (uldap_exists($data, $name)) {
            uldap_delete($data, $name);
            $changed = true;
            log_debug('ldap_write_string(%s): remove', $name);
        } else {
            #log_debug('ldap_write_string(%s): already removed', $name);
        }
    } else if (uldap_exists($data, $name)) {
        $old = nvl(uldap_value($data, $name));
        if ($val != $old) {
            uldap_replace($data, $name, $val);
            $changed = true;
            log_debug('ldap_write_string(%s): "%s" -> "%s"', $name, $old, $val);
        } else {
            #log_debug('ldap_write_string(%s): preserve "%s"', $attr, $val);			
        }
    } else {
        uldap_add($data, $name, $val);
        $changed = true;
        log_debug('ldap_write_string(%s): add "%s"', $name, $val);			
    }
    return $changed;
}


function ldap_read_dn (&$obj, &$at, $srv, &$data, $name) {
	return uldap_dn($data);
}


function ldap_write_dn (&$obj, &$at, $srv, &$data, $name, $val) {
    $prev = uldap_dn($data);
    log_debug('ldap_write_dn(%s): attr="%s" val="%s", prev="%s"',
                $srv, $at['name'], $val, $prev);
    if ($val == $prev || $val == '')  return false;
    uldap_set_dn($data, $val);
    return true;
}


function ldap_read_class (&$obj, &$at, $srv, &$data, $name) {
    return join_list(uldap_value($data, $name, true));
}


function ldap_write_class (&$obj, &$at, $srv, &$data, $name, $val) {
    $name = 'objectClass';
    $changed = false;
    $ca = array();
    $added = array();
    foreach (uldap_value($data, $name, true) as $c)
        $ca[strtolower($c)] = 1;
    foreach (split_list($val) as $c) {
        if (isset($ca[strtolower($c)]))  continue;
        uldap_add($data, $name, $c);
        $added[] = $c;
        $changed = true;
    }
    log_debug('ldap_write_class(%s): attr="%s" class="%s" changed=%d (%s)',
                $srv, $at['name'], $val, $changed, join_list($added));
    return $changed;
}


//
// we never try to read the password, just return some
// impossible to type string which will trigger a change condition
//
function ldap_read_pass (&$obj, &$at, $srv, &$data, $name) {
    return OLD_PASS;
}


function ldap_write_pass (&$obj, &$at, $srv, &$data, $name, $val) {
    return false;
}


function ldap_write_pass_final (&$obj, &$at, $srv, &$data, $name, $val) {
    $old = ldap_read_pass($obj, $at, $srv, $data, $name);
    if (empty($val) || $val == $old)
        return false;
    switch($srv) {
        case 'uni':
            return unix_write_pass_final($obj, $at, $srv, $data, $name, $val);
        case 'ads':
            return ad_write_pass_final($obj, $at, $srv, $data, $name, $val);
        case 'cgp':
            return cgp_write_pass_final($obj, $at, $srv, $data, $name, $val);
    }
    return false;
}


?>
