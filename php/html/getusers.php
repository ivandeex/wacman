<?php
// $Id$

// Sanity checking
define('LIBDIR','../lib/');
ini_set('display_errors',1);
error_reporting(E_ALL);

// General functions needed to proceed.
ob_start();
if (! is_readable(LIBDIR.'common.php')) {
    ob_end_clean();
    die("Fatal error: cannot read 'common.php'");
}
require LIBDIR.'common.php';
ob_end_clean();
// Start the show!


// ====================================================================

$servers = array(
    'uni' => array( disable => 1 ),    # Unix LDAP Server
    'ads' => array( disable => 1 ),    # Windows Active Directory
    'cgp' => array( disable => 1 ),    # CommuniGate Pro
    'cli' => array( disable => 1 )     # CommuniGate Pro - CLI interface
);


$config = array(
    'config_files'      => array('~/userman.ini'),
    'passfile'          => '~/userman.secret',
    'unix_user_classes' => 'top,person,organizationalPerson,inetOrgPerson,posixAccount,shadowAccount', # 'ntUser',
    'unix_group_classes'=> 'top,posixGroup',	
    'home_root'         => '/home',
    'ad_user_classes'   => 'top,user,person,organizationalPerson',	
    'ad_user_category'  => 'cn=Person,cn=Schema,cn=Configuration',
    'cgp_user_classes'  => 'top,person,organizationalPerson,inetOrgPerson,CommuniGateAccount',
    'cgp_group_classes' => 'top,person,organizationalPerson,inetOrgPerson,CommuniGateGroup',
    'cgp_alias_classes' => 'top,alias',
    'cgp_intercept_opts'=> 'Access,Append,Login,Mailbox,Partial,Sent,Signal',
    'cgp_buggy_ldap'    => 1,
    'cgp_password'      => 'cli',
    'cgp_pass_encryption'=> 'A-crpt',
    'cli_timeout'       => 3,
    'idle_interval'     => 60,
    'connect_timeout'   => 5,
    'language'          => 'ru',
    'locale'            => 'ru_RU.utf8',
    'show_splash'       => 0,
);


function get_server ($srv, $active = false) {
    if (! $servers[$srv])
        pla_error(_T('unknown ldap server "%s"', $srv));
    if (!active && $servers[$srv]['disable'])
        pla_error(_T('server "%s" is disabled', $srv));
    return $servers[$srv];
}

function strip_quotes ($str) {
  if (    (substr($str, 0, 1) == '"' && substr($str, -1, 1) == '"')
       || (substr($str, 0, 1) == "'" && substr($str, -1, 1) == "'"))
      return substr($str, 1, strlen($str) - 2);
  else
      return $str;
}

function get_credentials ($srv) {
    $cfg = get_server($srv);
    $user = $cfg['user'];
    $pass = empty($user) ? '' : $cfg['pass'];
    if (empty($pass)) {
        $file = empty($cfg['passfile']) ? $config['passfile'] : $cfg['passfile'];
        $f = fopen ($filename, 'r');
        if (!$f)
            log_error('cannot open passfile "%s"', $filename);
        $line = '';
        $no = 0;
        while (($line = fgets($f)) !== FALSE) {
            $no++;
            if (preg_match('/^\s*$/', $line) || preg_match('/^\s*#/', $line))
                continue;
            $parts = array();
            if (! preg_match("/^\s*([^\s'\"]+|'[^']*'|\"[^\"]*\")\s+".
                             "([^\s'\"]+|'[^']*'|\"[^\"]*\")\s+".
                             "([^\s'\"]+|'[^']*'|\"[^\"]*\")\s*$/",
                             $line, $parts)) {
                log_error('syntax error in line %d of "%s"', $no, $secret);
                continue;
            }
            $iserv = strip_quotes($parts[1]);
            $iuser = strip_quotes($parts[2]);
            $ipass = strip_quotes($parts[3]);
            //log_debug('secret: srv="%s" user="%s" pass="%s"', $iserv, $iuser, $ipass);
            if ($iserv == $srv) {
                if ((!empty($user) && ($iuser == $user || $iuser == '*')) || (empty($user) && $iuser != '*')) {
                    if (empty($user))
                        $user = $iuser;
                    $pass = $ipass;
                    break;
                }
            }
        }
        fclose($f);
        if (empty($user) || empty($pass))
            log_error('cannot find credentials for server "%s"', $srv);
    }
    return array('user' => $user, 'pass' => $pass);
}

function ldap_connect_all () {
    global $servers;
    foreach ($servers as $srv => $cfg) {
        log_info('connecting to "%s"', $srv);
        if (ldap_connect_to($srv) < 0)
            pla_error(_T('Connection to "%s" failed', $srv));
    }
}

function ldap_connect_to ($rv) {
    $cfg = get_server($srv);
    $cfg['name'] = $srv;
    $cfg['connected'] = 0;
    //if ($srv == 'cli')
    //    return cli_connect();
    if ($cfg['disable']) {
        $cfg['ldap'] = null;
        return 0;
    }
    if (empty($cfg['uri']))
        log_error('invalid uri for server "%s"', $srv);
    $creds = get_credentials($srv);
    $cfg['user'] = $creds['user'];
    $cfg['pass'] = $creds['pass'];
    $cfg['ldap'] = ldap_connect($cfg['uri']);
    if (! $cfg['ldap']) {
        log_info('error binding to server "%s"', $srv);
        return -1;
    }
    log_debug('connecting to server "%s"...', $srv);
    $okay = ldap_bind($cfg['ldap'], $cfg['user'], $cfg['pass']);
    if (! $okay) {
        log_info('cannot bind to server "%s": %s', $srv, ldap_error($cfg['ldap']));
        return -1;
    }
    $cfg['connected'] = 1;
    log_debug('successfully connected to server "%s"', $srv);
    return 0;	
}

function configure ($files) {
    global $config;
    global $servers;
    foreach ($files as $file) {
        if (substr($file, 0, 2) == '~/')
            $file = CONFDIR . substr($file, 2);
        $f = fopen($file, 'r');
        if (! $f) {
            log_error("$file: cannot open config file");
            continue;
        }
        $mode = 'config';
        $modes = array('config' => 1);
        $no = 0;
        foreach ($servers as $srv => $cfg) {
            $modes{$srv} = 1;
        }
        $line = '';
        while (($line = fgets($f)) !== FALSE) {
            $no++;
            if (preg_match('/^\s*$/', $line) || preg_match('/^\s*#/', $line))
                continue;
            $parts = array();
            if (preg_match('/^\s*\[\s*(\S+)\s*\]\s*$/', $line, $parts)) {
                $mode = $parts[1];
                if (! $modes[$mode])
                    log_error('incorrect section "%s" in %s: %s', $mode, $file, $line);
		continue;
            } else if (preg_match('/^\s*(\S+)\s*=\s*(.*?)\s*$/', $line, $parts)) {
                 $name = strip_quotes($parts[1]);
                 $val = $parts[2];
                 if (preg_match('/^\[\s*(.*?)\s*\]$/', $val, $parts)) {
                     $val = preg_split('/\s*,\s*/', $parts[1]);
                     foreach ($val as &$v) { $v = strip_quotes($v); }
                 } else {
                     $val = strip_quotes($parts[2]);
                 }
                 if ($mode == 'config') {
                     $config[$name] = $val;				
                 } else {
                     $servers[$mode][$name] = $val;
                 }
            } else {
                log_error('incorrect line in %s: %s', $file, $line);
            }
        }
        fclose($f);
    }

    // some defaults
    $alg = empty($config['cgp_password']) ? 'cli' : strtolower($config['cgp_password']);
    if (! preg_match('/^(cli|sha|clear)$/', $alg))
        log_error("CGP password type \"$alg\" is not one of: cli, sha, clear");
    $config['cgp_password'] = $alg;

    if (empty($config['start_user_id']))
        $config{start_user_id} = 1000;
    if (empty($config['start_group_id']))
        $config{start_group_id} = 1000;
}

configure($config['config_files']);
//ldap_connect('uni');
pla_error('<br><br>servers:<br>'.print_r($servers,true).'<br><br>config:<br>'.print_r($config,true));

?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.0//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic10.dtd">
<html>
<head><title>Users</title></head>
<body>
<p>Users</p>
</body>
</html>

