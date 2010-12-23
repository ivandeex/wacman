<?php
// $Id$

// Interface with CommuniGate server


function cgp_read_domain_intercept (&$at, $srv, $ldap, $name) {
	$res = cli_cmd('GetDomainMailRules %s', get_config('mail_domain'));
	if ($res['code']) {
		log_info('cgp_read_domain_intercept error: %s', $res->{msg});
		return 0;
	}
/*
    my $rules = str2array($res->{out});
    log_info('cgp_read_domain_intercept: %s', array2str($rules));
    my $ret = -1;
    for my $rule ($rules) {
        if ($$rule[1] =~ /\#Redirect/) {
            if (ref $$rule[2] && ref $$rule[3]) {
                if (nvl($$rule[3][1]) eq $config{cgp_listener}) {
                    $ret = 1;
                    last;
                }
            }
        }
    }

    log_info('cgp_read_domain_intercept: ret = %d', $ret);
    $domain_intercept = bool2str($ret > 0 ? 1 : 0);
    return $domain_intercept;
*/
    return 0;
}


function cgp_write_domain_intercept (&$at, $srv, $ldap, $name, $val) {
/*
    my $rule = [
        $new, '"#Redirect"',
        [ '"Human Generated"', '"---"'],
        [ '"Mirror to"', $config{cgp_listener} ]
    ];
    my $out = array2str($rule);
    log_info('cgp_write_domain_intercept: rule = %s', $out);
    my $res = cli_cmd('SetDomainMailRules %s %s', $config{mail_domain}, $out);
    if ($res->{code}) {
        log_info('cgp_write_domain_intercept error: %s', $res->{msg});
        return 0;
    }
*/
    return 1;
}


function cgp_get_server_intercept () {
/*
    return 0 if defined $server_intercept;
    my $res = cli_cmd('GetServerIntercept');
    if ($res->{code}) {
        log_info('cgp_get_server_intercept error: %s', $res->{msg});
        return -1;
    }
    $server_intercept = str2dict($res->{out});
    log_debug('cgp_get_server_intercept: %s', dict2str($server_intercept));
*/
	return 0;
}


function cgp_read_user_intercept (&$at, $srv, $ldap, $name) {
/*
    my $mail = nvl( $ldap->get_value('mail') );
    return bool2str(0) if $mail eq '' || cgp_get_server_intercept() < 0;
    my $ret = bool2str(defined $server_intercept->{$mail});
    log_debug('cgp_read_user_intercept(%s): %s', $mail, $ret);
    return $ret;
*/
	return 0;
}


function cgp_write_user_intercept (&$at, $srv, $ldap, $name, $val) {
/*
    my $old = str2bool($at->{old});
    my $new = str2bool($at->{val});
    return 0 if $old == $new;
    return 0 if cgp_get_server_intercept() < 0;
    my $mail = nvl( $ldap->get_value('mail') );
    if ($new) {
        my $opt = {};
        $opt->{SendTo} = $config{cgp_listener};
        for (split_list $config{cgp_intercept_opts}) { $opt->{$_} = 'YES' }
        $server_intercept->{$mail} = $opt;
    } else {
        delete $server_intercept->{$mail};
    }
    my $out = dict2str($server_intercept);
    my $res = cli_cmd('SetServerIntercept %s', $out);
    if ($res->{code}) {
        log_info('cgp_write_user_intercept(%s) write error: %s ("%s")',
                $mail, $res->{msg}, $out);
        return 0;
    }
    log_debug('cgp_write_user_intercept(%s) success: %s', $mail, $out);*/
    return 1;
}


function cgp_modify_mail_group ($srv, $gid, $uid, $action) {
/*
    log_debug('will be %s\'ing mail user "%s" in group "%s"...', $action, $uid, $gid);
    my $retval;
    if ($config{cgp_buggy_ldap}) {
        my $gname = $gid . '@' . $config{mail_domain};
        my $res = cli_cmd('GetGroup %s', $gname);
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
            $res = cli_cmd("SetGroup %s %s", $gname, $newparams);
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


function cgp_read_aliases (&$at, $srv, $ldap, $name) {
    $dn = nvl(uldap_dn($ldap));
    if ($dn == '')
        return '';
    $aliases = array();
    $telnum = '';
    $old_telnum = get_attr($at['obj'], 'telnum', array('orig' => 1));
    $entries = uldap_search($srv, "(&(objectClass=alias)(aliasedObjectName=$dn))", array('uid'));
    $telnum_pat = '/^\d{'.get_config('telnum_len',3).'}$/';
    foreach ($entries as $e) {
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
        init_attr($at['obj'], 'telnum', $telnum);
    return $aliases;
}


function cgp_write_aliases_final (&$at, $srv, $ldap, $name, $val) {
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


function cgp_read_mail_groups (&$at, $srv, $ldap, $name) {
    $uid = nvl(uldap_value($ldap, 'uid'));
    if ($uid == '')
        return '';
    $entries = uldap_search($srv, "(&(objectClass=CommuniGateGroup)(groupMember=$uid))", array('uid'));
    $arr = array();
    foreach ($entries as $ue)
        $arr[] = uldap_value($ue, 'uid');
    return join_list($arr);
}


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
    $cfg['cli'] = $cli = new CLI;
    if ($cfg['debug'])
        $cli->SetDebug(2);
    $cli->Login($cfg['host'], $cfg['port'], $cfg['user'], $cfg['pass']);
    if (! $cli->isSuccess()) {
        log_error('cannot bind to CLI: ' . $cli->getErrMessage());
        return -1;
    }
    log_debug('connected to cgp cli');
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
    $cfg =& get_server('cli', true);
    if (!$cfg['connected']) {
        $msg = $cfg['disable'] ? 'CGP disabled' : 'CGP not connected';
        set_error($msg);
        return array('code' => -1, 'error' => $msg, 'data' => array());
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
    return array('code' => $cli->getErrCode(), 'error' => $cli->getErrMessage(), 'data' => array());
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
