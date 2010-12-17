<?php
// $Id$

// Interface with CommuniGate server


function cli_connect () {
    $cfg =& get_server('cli');
    $uri = $cfg['uri'];
    if (! preg_match('!^\s*(?:\w+\://)?([\w\.\-]+)(?:\s*\:\s*(\d+))[\s/]*$!', $uri, $parts)) {
        log_error('invalid uri for server CLI');
        return -1;
    }
    $cfg['host'] = empty($parts[1]) ? 'localhost' : $parts[1];
    $cfg['port'] = empty($parts[2]) ? 106 : $parts[2];
    $creds = get_credentials('cli');
    $cfg['user'] = $creds['user'];
    $cfg['pass'] = $creds['pass'];
    $cfg['connected'] = 0;
    #log_debug('connecting to CLI: host %s port %s as user %s pass %s',
    #          $cfg['host'], $cfg['port'], $cfg['user'], $cfg['pass']);
    $cfg['cli'] = $cli = new CLI;
    if ($cfg['debug'])
        $cli->SetDebug(1);
    $cli->Login($cfg['host'], $cfg['port'], $cfg['user'], $cfg['pass']);
    if (! $cli->isSuccess()) {
        log_error('cannot bind to CLI: ' . $cli->getErrMessage());
        return -1;
    }
    #log_debug('successfully connected to CLI');
    $cfg['connected'] = 1;
    return 0;
}


function & get_cli () {
    $cfg =& get_server('cli');
    return $cfg['cli'];
}


function cli_disconnect () {
    $cfg =& get_server('cli');
    if ($cfg['connected']) {
        $cli =& $cfg['cli'];
        $cli->Logout();
        $cfg['connected'] = 0;
    }
}


function cli_cmd () {
    $cfg =& get_server('cli');
    if (! $cfg['connected']) {
        set_error("server CLI is not connected");
        return null;
    }
    $cli = $cfg['cli'];
    $args = func_get_args();
    $func = array_shift($args);
    $ret = call_user_func_array(array($cli, $func), $args);

    if ($cli->isSuccess()) {
        set_error();
        return array('code' => 0, 'error' => '', 'data' => $ret);
    }

    log_error("CLI error in $func: " . $cli->getErrMessage());
    return array('code' => $cli->getErrCode(), 'error' => $cli->getErrMessage(), 'data' => null);
}


function dict2str ($d)
{
    return __dict2str($d);
}


function __dict2str ($d)
{
	$s = '{ ';
	$keys = array_keys($d);
	sort($keys);
	foreach ($keys as $k) {
		$v = $d[$k];
		$s .= $k . ' = ';
		if (is_array($v)) {
			$s .= __dict2str($v);
		} else {
            $x = preg_replace('/[0-9a-xA-Z_\@]/', '', $v);
			$q = empty($x) ? '' : '"';
			if (preg_match('/^\".*?\"$/', $v) || preg_match('/^\(.*?\)$/', $v)) {
				$q = '';
			} else {
				$v = preg_replace('/\"/', '\\\"', $v);
			}
			$s .= $q.$v.$q;
		}
		$s .= '; ';
	}
	return $s . '}';
}


?>
