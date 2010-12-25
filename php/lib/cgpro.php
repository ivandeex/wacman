<?php
// $Id$

// Interface with CommuniGate server

function cgp_read_domain_intercept (&$obj, &$at, $srv, &$ldap, $name) {
    if (! isset($ldap['domain_mail_rules'])) {
        $res = cgp_cmd($srv, 'GetDomainMailRules', get_config('mail_domain'));
        if ($res['code']) {
            log_error('cgp_read_domain_intercept error: %s', $res['error']);
            return '';
        }
        if (! is_array($res['data'])) {
            log_error('cgp_read_domain_intercept: expected array of rules');
            return '';
        }
        $ldap['domain_mail_rules'] = $res['data'];
    }
    $rule_idx = -1;
    foreach ($ldap['domain_mail_rules'] as $idx => &$rule) {
        if (is_array($rule) || count($rule) >= 4) {
            list($prio, $name, $cond, $steps) = $rule;
            if (strpos($name, '#Redirect') !== false && is_array($steps)) {
                foreach ($steps as $step) {
                    if (is_array($step) && count($step) == 2) {
                        if (trim($step[0]) === 'Mirror to'
                                && trim($step[1] == get_config('cgp_listener'))) {
                            $rule_idx = $idx;
                            break;
                        }
                    }
                }
            }
        }
    }
    $ldap['domain_intercept_mail_rule_idx'] = $rule_idx;
    $val = bool2str($rule_idx >= 0);
    log_debug('cgp_read_domain_intercept: %s (idx=%s)', $val, $rule_idx);
    return $val;
}


function cgp_write_domain_intercept (&$obj, &$at, $srv, &$ldap, $name, $val) {
    $old = str2bool(cgp_read_domain_intercept ($obj, $at, $srv, $ldap, $name));
    $val = str2bool($val);
    if ($val === $old || !isset($ldap['domain_mail_rules']))
        return false;
    if ($val) {
        $ldap['domain_mail_rules'][] = array(
                0,
                '#Redirect',
                array( array('Human Generated', '---') ),
                array( array('Mirror to', get_config('cgp_listener') ) )
            );
        $ldap['domain_intercept_mail_rule_idx'] = count($ldap['domain_mail_rules']) - 1;
    } else {
        array_splice($ldap['domain_mail_rules'], $ldap['domain_intercept_mail_rule_idx'], 1, null);
        $ldap['domain_intercept_mail_rule_idx'] = -1;
    }
    $res = cgp_cmd($srv, 'SetDomainMailRules', get_config('mail_domain'));
    if ($res['code']) {
        log_error('cgp_write_domain_intercept error: %s', $res['error']);
        return false;
    }
    return true;
}


function cgp_read_user_intercept (&$obj, &$at, $srv, &$ldap, $name) {
    if (! isset($ldap['server_intercept'])) {
        $res = cgp_cmd($srv, 'GetServerIntercept', get_config('mail_domain'));
        if ($res['code']) {
            log_error('cgp_read_user_intercept error: %s', $res['error']);
            return '';
        }
        if (! is_array($res['data'])) {
            log_error('cgp_read_user_intercept: expected array of mails');
            return '';
        }
        $ldap['server_intercept'] = $res['data'];
    }
    $mail = nvl(get_attr($obj, 'mail'));
    if (empty($mail))
        return '';
    $val = bool2str(empty($mail) ? false : array_search($mail, $ldap['server_intercept']));
    log_debug('cgp_read_user_intercept(%s): %s', $mail, $val);
    return $val;
}


function cgp_write_user_intercept (&$obj, &$at, $srv, &$ldap, $name, $val) {
    $old = str2bool(cgp_read_domain_intercept ($obj, $at, $srv, $ldap, $name));
    $val = str2bool($val);
    $mail = nvl(get_attr($obj, 'mail'));
    if ($val === $old || !isset($ldap['server_intercept']) || empty($mail))
        return false;
    if ($val) {
        $ldap['server_intercept'][] = $mail;
    } else {
        unset($ldap['server_intercept'][$mail]);
    }
    $res = cgp_cmd($srv, 'SetServerIntercept', $ldap['server_intercept']);
    if ($res['code']) {
        log_error('cgp_write_user_intercept error: %s', $res['error']);
        return false;
    }
    return true;
}


function cgp_modify_mail_group ($srv, $gid, $uid, $action) {
/*
    log_debug('will be %s\'ing mail user "%s" in group "%s"...', $action, $uid, $gid);
    my $retval;
    if ($config{cgp_buggy_ldap}) {
        my $gname = $gid . '@' . $config{mail_domain};
        my $res = cgp_cmd($srv, 'GetGroup', $gname);
        if ($res->{code} == 0) {
            my $dict = str2dict($res->{out});
            log_debug('group "%s" members: %s', $gid, dict2str($dict));
            my $old = nvl($dict->{Members});
            $old = $1 if $old =~ /^\(\s*(.*?)\s*\)$/;
            my $new = $action eq 'add' ? append_list($old, $uid) : remove_list($old, $uid);
            log_debug('group %s members: old=(%s) new=(%s)', $gid, $old, $new);
            return 'SAME' if $old eq $new;
            $dict->{Members} = "($new)";
            my $newparams = dict2str($dict);
            log_debug('newparams: "%s"', $newparams);
            $res = cgp_cmd($srv, 'SetGroup', $gname, $newparams);
            if ($res->{code} == 0) {
                $retval = 'OK';
            } else {
                message_box('error', 'close',
                        _T('Error modifying mail group "%s": %s', $gid, $res->{msg}));
                $retval = $res->{msg};
            }
        } else {
            message_box('error', 'close',
                        _T('Error reading mail group "%s": %s', $gid, $res->{msg}));
            $retval = $res->{msg};
        }
    } else {
        my $res = ldap_search('cgp', "(&(objectClass=CommuniGateGroup)(uid=$gid))",
                                ['groupMember']);
        my $grp = $res->pop_entry;
        if ($res->code || !$grp) {
            log_info('cannot find mail group "%s" for modification', $gid);
            return $res->error;
        }
        my ($old, $new, @new, $exists);
        $exists = $grp->exists('groupMember') ? 1 : 0;
        $old = $exists ? join_list($grp->get_value('groupMember')) : '';
        $new = $action eq 'add' ? append_list($old, $uid) : remove_list($old, $uid);
        @new = split_list $new;
        if ($old eq $new) {
            log_debug('mail group "%s" wont change with user "%s": (%s) = (%s)',
                    $gid, $uid, $old, $new);
            return 'SAME';
        }
        if ($exists) {
            $grp->replace('groupMember' => \@new);
        } else {
            $grp->add('groupMember' => \@new);
        }
        log_debug('modify mail group "%s": user="%s" action="%s" exists="%s" new="%s"',
                    $gid, $uid, $action, $exists, join_list @new);
        $res = ldap_update('cgp', $grp);
        if ($res->code) {
            log_info('%s mail user "%s" in group "%s" error: %s',
                    $action, $uid, $gid, $res->error);
            $retval = $res->error;
        } else {
            log_debug('success %s\'ing mail user "%s" in group "%s": [%s] -> [%s]...',
                        $action, $uid, $gid, $old, $new);
            $retval = 'OK';
        }
    }
    my $sel_mgroup = $mailgroup_obj;
    if (!$sel_mgroup->{changed} && get_attr($sel_mgroup, 'uid') eq $uid) {
        # refresh gui for this mail group (FIXME)
        mailgroup_load();
    }
    return $retval;
*/
    return 0;
}


function cgp_read_aliases (&$obj, &$at, $srv, &$ldap, $name) {
    $dn = nvl(uldap_dn($ldap));
    if ($dn == '')
        return '';
    $aliases = array();
    $telnum = '';
    $old_telnum = get_attr($obj, 'telnum', array('orig' => 1));
    $res = uldap_search($srv, "(&(objectClass=alias)(aliasedObjectName=$dn))", array('uid'));
    $telnum_pat = '/^\d{'.get_config('telnum_len',3).'}$/';
    foreach (uldap_entries($res) as $e) {
        $alias = uldap_value($e, 'uid');
        if ($old_telnum == '' && $telnum == '' && preg_match($telnum_pat, $alias)) {
			$telnum = $alias;
        } else {
            $aliases[] = $alias;
        }
    }
    $aliases = join_list($aliases);
    log_debug('read aliases: telnum="%s" aliases="%s"', $telnum, $aliases);
    if ($telnum != '')
        set_attr($obj, 'telnum', $telnum);
    return $aliases;
}


function cgp_write_aliases_final (&$obj, &$at, $srv, &$ldap, $name, $val) {
    $old = append_list(nvl($at['old']), get_attr($obj, 'telnum', array('orig' => 1))); # FIXME!!!
    $new = append_list(nvl($at['val']), get_attr($obj, 'telnum'));
    log_debug('write_aliases_final: old="%s" new="%s"', $old, $new);
    if ($old == $new)
        return 0;
    if (get_config('cgp_buggy_ldap')) {
        $mail = get_attr($obj, 'mail');
        $res = cgp_cmd($srv, 'SetAccountAliases', $mail, join_list(split_list($new)));
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


function cgp_read_mail_groups (&$obj, &$at, $srv, &$ldap, $name) {
    $uid = nvl(uldap_value($ldap, 'uid'));
    if ($uid == '')
        return '';
    $res = uldap_search($srv, "(&(objectClass=CommuniGateGroup)(groupMember=$uid))", array('uid'));
    $arr = array();
    foreach (uldap_entries($res) as $e)
        $arr[] = uldap_value($e, 'uid');
    return join_list($arr);
}


function cgp_write_pass_final (&$obj, &$at, $srv, &$ldap, $name, $val) {
    global $servers;
    $ldap =& $servers[$srv]['ldap'];

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
            $res = cgp_cmd($srv, 'UpdateAccountSettings', $mail,
                            array('UseAppPassword' => 'YES') );
            if ($res['code'])
                log_info('Cannot enable CGP passwords for %s: %s', $mail, $res['error']);
            $res = cgp_cmd($srv, 'UpdateAccountSettings', $mail,
                            array('PasswordEncryption' => $passenc) );
            if ($res['code'])
                log_info('Cannot change encryption for %s to %s: %s',
                        $mail, $passenc, $res['msg']);
            if (get_config('debug'))
                $res = cgp_cmd($srv, 'GetAccountEffectiveSettings', $mail);
        }
        $res = cgp_cmd($srv, 'SetAccountPassword', $mail, $cgpass);
        if (! $res['code'])
            return 1;
        log_error(_T('Cannot change password for "%s" on "%s": %s',
                    $mail, $srv, $res['error']));
        return 0;
    }

    if ($alg == 'sha') {
        $cgpass = "\x2{SHA}" . base64_encode(sha1($val, true));
    } else {
        $cgpass = nvl($val);
    }
    log_debug('cgpass=%s', $cgpass);
    return 1;
}


////////////////////////////////////////////////////
//    CLI interface
//


function cgp_connect ($srv) {
    $cfg =& get_server($srv);
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
    $cfg['connected'] = false;
    $cfg['failed'] = true;
    $cfg['cli'] = new CLI;
    $cli =& $cfg['cli'];
    if ($cfg['debug'])
        $cli->SetDebug(2);
    if (! $cli->Login($cfg['host'], $cfg['port'], $cfg['user'], $cfg['pass'])) {
        log_error('cannot bind to CLI: ' . $cli->getErrMessage());
        return -1;
    }
    log_debug('connected to cgp cli');
    $cfg['connected'] = true;
    $cfg['failed'] = false;
    return 0;
}


function cgp_disconnect ($srv) {
    $cfg =& get_server($srv);
    if (!$cfg['connected'])
        return;
    if (isset($cfg['cli'])) {
        $cfg['cli']->Logout();
        unset($cfg['cli']);
    }
    $cfg['connected'] = $cfg['failed'] = false;
}


// cgp_cmd($srv_name, $func_name, $func_args...)
function cgp_cmd () {
    $args = func_get_args();
    $srv = array_shift($args);
    $func = array_shift($args);
    $cfg =& get_server($srv, true);
    srv_connect($srv);
    if (!$cfg['connected'] || !isset($cfg['cli'])) {
        $msg = $cfg['disable'] ? 'CGP disabled' :
                (isset($cfg['cli']) ? 'CGP not connected' : 'CGP is not CLI');
        set_error($msg);
        return array('code' => -1, 'error' => $msg, 'data' => array());
    }
    $cli = $cfg['cli'];
    $ret = call_user_func_array(array($cli, $func), $args);

    if ($cli->isSuccess()) {
        set_error();
        return array('code' => 0, 'error' => '', 'data' => $ret);
    }

    log_error("CLI error in $func: " . $cli->getErrMessage());
    return array('code' => $cli->getErrCode(), 'error' => $cli->getErrMessage(), 'data' => array());
}


function cgp_string ($srv, $data) {
    $cfg =& get_server($srv, true);
    if (!$cfg['connected'] || !isset($cfg['cli'])) {
        log_error('cgp_string(%s): invalid CGP state', $srv);
        return '';
    }
    return $cfg['cli']->printWords($data);
}


?>
