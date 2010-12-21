<?php
// $Id$

// Configuration file parser

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
    'min_telnum'        => 501,
    'max_telnum'        => 599,
    'telnum_len'        => 3,
    'cli_timeout'       => 3,
    'idle_interval'     => 60,
    'connect_timeout'   => 5,
    'language'          => 'en',
    'locale'            => 'en_US.utf8',
    'show_splash'       => 0,
    'theme_css'         => 'js/ext/resources/css/ext-all.css',
    'ext_js'            => 'js/ext/adapter/ext/ext-base.js,js/ext/ext-all.js',
    'btm_button_class'  => ''
);

function get_config($name, $defval = null) {
    global $config;
    return (isset($config[$name]) ? $config[$name] : $defval);
}

function strip_quotes ($str) {
  if (    (substr($str, 0, 1) == '"' && substr($str, -1, 1) == '"')
       || (substr($str, 0, 1) == "'" && substr($str, -1, 1) == "'"))
      return substr($str, 1, strlen($str) - 2);
  else
      return $str;
}

function configure ($files = null) {
    global $config;
    if (empty($files))
        $files = $config['config_files'];
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
        foreach (get_server_names() as $srv)
            $modes{$srv} = 1;
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
                 if (preg_match('/^\[\s*(.*?)\s*\]$/', $val, $subparts)) {
                     $val = preg_split('/\s*,\s*/', $subparts[1]);
                     foreach ($val as &$v) { $v = strip_quotes($v); }
                 } else {
                     $val = strip_quotes($parts[2]);
                 }
                 if ($mode == 'config') {
                     $config[$name] = $val;				
                 } else {
                     global $servers;
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

function get_credentials ($srv) {
    $cfg = &get_server($srv);
    $user = isset($cfg['user']) ? $cfg['user'] : '';
    $pass = empty($user) ? '' : $cfg['pass'];
    if (empty($pass)) {
        $file = get_config('passfile');
        if (substr($file, 0, 2) == '~/')
            $file = CONFDIR . substr($file, 2);
        $f = fopen ($file, 'r');
        if (!$f)
            log_error('cannot open passfile "%s"', $file);
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
                if ((!empty($user) && ($iuser == $user || $iuser == '*'))
                        || (empty($user) && $iuser != '*')) {
                    if (empty($user))  $user = $iuser;
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

?>
