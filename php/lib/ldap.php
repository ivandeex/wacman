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
    $cfg =& $servers[$srv];
    if (! $allow_disabled && $cfg['disable'])
        error_page(_T('server "%s" is disabled', $srv));
    return $cfg;
}


///////////////////////////////////////////////
// Protocol basics
//

function srv_connect ($srv) {
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

    if ($srv == 'cli')
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

    if ($srv == 'ads') {
        // active directory requires ldap protocol v3
        @ldap_set_option($cfg['ldap'], LDAP_OPT_PROTOCOL_VERSION, 3);
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


function srv_disconnect_all () {
    global $servers;
    foreach ($servers as $srv => &$cfg) {
        if (isset($cfg['disable']) && $cfg['disable'])
            continue;
        if (!(isset($cfg['connected']) && $cfg['connected']))
            continue;
        if ($srv == 'cli') {
            cgp_disconnect($srv);
        } else {
            @ldap_close($cfg['ldap']);
        }
        unset($cfg['ldap']);
        $cfg['connected'] = false;
        $cfg['failed'] = false;
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
    } else {
        $count = 0;
    }
    for ($i = 0; $i < $count; $i++)
        $entries[] = $res['data'][$i];
    return $entries;
}

function uldap_pop ($res) {
    if (isset($res['data']['count']) && $res['data']['count'] > 0)
        return $res['data'][0];
    return null;
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
    $cfg =& get_server($srv, true);
    srv_connect($srv);
    $res = array('data' => array('count' => 0));
    if (! $cfg['connected']) {
        $res['code'] = -1;
        $res['error'] = "$srv: not connected";
        return $res;
    }
    $conn = $cfg['ldap'];
    if (is_null($attrs))
        $attrs = array('*');
    $handle = @ldap_search($conn, $cfg['base'], $filter, $attrs);
    if ($handle === FALSE) {
        $res['code'] = ldap_errno($conn);
        $res['error'] = ldap_error($conn);
        log_debug('LDAP(%s) search[%s] attrs[%s] search failed: %s',
                    $srv, $filter, join_list($attrs), $res['error']);
        return $res;
    }
    $res['data'] = @ldap_get_entries($conn, $handle);
    if ($res['data'] === FALSE) {
        $res['code'] = ldap_errno($conn);
        $res['error'] = ldap_error($conn);
        $res['data'] = array('count' => 0);
        log_debug('LDAP(%s) search[%s] attrs[%s] entries failed: %s',
                    $srv, $filter, join_list($attrs), $res['error']);
        return $res;
    }
    $res['code'] = 0;
    $res['error'] = '';
    set_error();
    if ($cfg['debug'])
        log_debug('LDAP(%s) search[%s]: %s', $srv, $filter, json_encode(uldap_convert_array($res['data'])));
    return $res;
}


//////////////////////////////////////////////////////////////
// Readers / Writers
//

function ldap_read_none () {
    return '';
}


function ldap_write_none () {
    return 0;
}


function ldap_read_string (&$obj, &$at, $srv, $ldap, $name) {
    return nvl(uldap_value($ldap, $name));
}


function ldap_write_string (&$obj, &$at, $srv, $ldap, $name, $val) {
    $changed = 0;
    if (empty($val)) {
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


function ldap_read_dn (&$obj, &$at, $srv, $ldap, $name) {
	return nvl(uldap_dn($ldap));
}


function ldap_write_dn (&$obj, &$at, $srv, $ldap, $name, $val) {
    $prev = nvl(uldap_dn($ldap));
    $val = nvl($val);
    log_debug('ldap_write_dn(%s): attr="%s" dn="%s", prev="%s"',
                $srv, $at['name'], $val, $prev);
    if ($val == $prev || $val == '')
        return 0;
    uldap_set_dn($ldap, $val);
    return 1;
}


function ldap_read_class (&$obj, &$at, $srv, $ldap, $name) {
    return join_list(uldap_value($ldap, $name));
}


function ldap_write_class (&$obj, &$at, $srv, $ldap, $name, $val) {
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


function ldap_read_pass (&$obj, &$at, $srv, $ldap, $name) {
    global $servers;
    $val = '';
    if (! get_config('show_password') || $servers['cgp']['disable']) {
        $val = OLD_PASS;
    } else if ($srv == 'cgp') {
        $val = ldap_read_string($at, $srv, $ldap, $name);
    }
    return( $at['oldpass'] = nvl($val) );
}


function ldap_write_pass (&$obj, &$at, $srv, $ldap, $name, $val) {
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


function ldap_write_pass_final (&$obj, &$at, $srv, $ldap, $name, $val) {
    if ($at['desc']['verify'] || $val == nvl($at['oldpass']))
        return 0;
    if ($srv == 'uni')
        return unix_write_pass_final($at, $srv, $ldap, $name, $val);
    if ($srv == 'cgp')
        return cgp_write_pass_final($at, $srv, $ldap, $name, $val);
    return 0;
}


?>
