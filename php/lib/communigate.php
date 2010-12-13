<?php
// $Id: common.php 1580 2010-12-13 12:59:13Z vitki $

// Interface with CommuniGate server

function cli_connect () {
    $cfg = &get_server('cli');
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
    log_debug('connecting to CLI: host %s port %s as user %s pass %s',
              $cfg['host'], $cfg['port'], $cfg['user'], $cfg['pass']);
    $cfg['cli'] = $cli = new CLI;
    if ($cfg['debug'])
        $cli->SetDebug(1);
    $cli->Login($cfg['host'], $cfg['port'], $cfg['user'], $cfg['pass']);
    if (! $cli->isSuccess()) {
        log_error('cannot bind to CLI: ' . $cli->getErrMessage());
        return -1;
    }
    log_debug('successfully connected to CLI');
    $cfg['connected'] = 1;
    return 0;
}

function &get_cli () {
    $cfg = &get_server('cli');
    return $cfg['cli'];
}

function cli_disconnect () {
    $cfg = &get_server('cli');
    if ($cfg['connected']) {
        $cli = $cfg['cli'];
        $cli->Logout();
        $cfg['connected'] = 0;
    }
}

function cli_cmd () {
    $cfg = &get_server('cli');
    if (! $cfg['connected']) {
        set_error("server CLI is not connected");
        return null;
    }
    $cli = $cfg['cli'];
    $args = func_get_args();
    $func = array_shift($args);
    $ret = call_user_func_array(array($cli, $func), $args);
    log_info("args=".print_r($args,1)." func=$func ret=".print_r($ret,1));
    if ($cli->isSuccess()) {
        set_error();
    } else {
        log_error("CLI error in $func: " . $cli->getErrMessage());
        return null;
    }
    return $ret;
}

?>
