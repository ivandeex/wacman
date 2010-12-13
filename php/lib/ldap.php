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

function &get_server ($srv, $allow_disabled = false) {
    global $servers;
    if (! isset($servers[$srv]))
        pla_error(_T('unknown ldap server "%s"', $srv));
    $cfg = &$servers[$srv];
    if (! $allow_disabled && $cfg['disable'])
        pla_error(_T('server "%s" is disabled', $srv));
    return $cfg;
}

function ldap_connect_to ($srv) {
    global $servers;
    $cfg = &get_server($srv, true);
    $cfg['name'] = $srv;
    $cfg['connected'] = 0;
    //if ($srv == 'cli')
    //    return cli_connect();
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

function ldap_connect_all () {
    foreach (get_server_names() as $srv) {
        log_info('connecting to "%s"', $srv);
        if (ldap_connect_to($srv) < 0)
            pla_error(_T('Connection to "%s" failed', $srv));
    }
}

function convert_ldap_array ($src) {
    if (! is_array($src) || ! isset($src['count']))
        return $src;
    if ($src['count'] == 1)
        return $src[0];
    $dst = array();
    $got_named = 0;
    foreach (array_keys($src) as $key) {
        if (! preg_match('/^\d+$/', $key) && $key != 'count') {
            $got_named = 1;
            continue;
        }
    }
    foreach ($src as $key => $val) {
        if ($key == 'count' || ($got_named && preg_match('/^\d+$/', $key)))
            continue;
        $dst[$key] = convert_ldap_array($val);
    }
    return $dst;
}

function ldap_search_for ($srv, $filter, $attrs = null, $params = null)
{
    $cfg = &get_server($srv, true);
    $result = array();
    if ($cfg['connected']) {
        $res = @ldap_search($cfg['ldap'], $cfg['base'], $filter, $attrs);
        if ($res !== FALSE) {
            $entries = @ldap_get_entries($cfg['ldap'], $res);
            if ($entries === FALSE) {
                log_error('ldap_search for "%s" on "%s" failed: %s',
                          $filter, $srv, ldap_error($cfg['ldap']));
            } else {
                set_error();
                $result = convert_ldap_array($entries);
            }
        }
    }
    return $result;
}

?>
