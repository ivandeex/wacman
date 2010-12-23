<?php
// $Id$

// Return next available ids

require '../lib/common.php';

uldap_connect_all();
send_json_headers();

$which = isset($_GET['which']) ? $_GET['which'] : '';
if (empty($which)) {
    echo json_error("which: required parameter wrong or not specified");
    uldap_disconnect_all();
    exit;
}

switch ($which) {
    case 'unix_uidn':
        $next_uidn = 0;
        $res = uldap_search('uni', '(objectClass=posixAccount)', array('uidNumber'));
        foreach (uldap_entries($res) as $usr) {
            $uidn = uldap_value($usr, 'uidNumber');
            if ($uidn > $next_uidn)
                $next_uidn = $uidn;
        }
        echo($next_uidn > 0 ? $next_uidn + 1 : get_config('start_user_id'));
        break;

    case 'unix_gidn':
        $next_gidn = 0;
        $res = uldap_search('uni', '(objectClass=posixGroup)', array('gidNumber'));
        foreach (uldap_entries($res) as $grp) {
            $gidn = uldap_value($grp, 'gidNumber');
            if ($gidn > $next_gidn)
                $next_gidn = $gidn;
        }
        echo($next_gidn > 0 ? $next_gidn + 1 : get_config('start_group_id'));
        break;

    case 'cgp_telnum':
        $domain = get_config('mail_domain');
        $res1 = cli_cmd('ListAccounts', $domain);
        $telnums = array();
        $telnum_pat = '/^\d{'.get_config('telnum_len',3).'}$/';
        foreach ($res1['data'] as $muid => $mutype) {
            $email = $muid.'@'.$domain;
            $res2 = cli_cmd('GetAccountAliases', $email);
            foreach ($res2['data'] as $alias) {
                if (preg_match($telnum_pat, $alias))
                    $telnums[$alias] = 1;
            }
            #$res2 = cli_cmd('GetAccountTelnums', $email);
            #foreach ($res2['data'] as $telnum)
            #    $telnums[$telnum] = 1;
        }

        list($min_telnum, $max_telnum) = array(get_config('min_telnum'), get_config('max_telnum'));
        for ($telnum = $min_telnum; $telnum <= $max_telnum; $telnum++) {
            if (! isset($telnums[$telnum])) {
                echo $telnum;
                break;
            }
        }
        echo '';
        break;

    default:
        echo '0';
        log_error('unknown id type "%s"', $which);
        break;
}

uldap_disconnect_all();
?>
