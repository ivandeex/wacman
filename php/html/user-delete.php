<?php
// $Id$

// Delete user object

require '../lib/common.php';

send_json_headers();
$id = nvl(isset($_GET['uid']) ? $_GET['uid'] : '');
if (empty($id)) {
    echo json_error("uid: required parameter wrong or not specified");
    exit;
}
if (is_reserved($id)) {
    echo json_error("Cannot delete reserved object");
    exit;
}

// Find Unix, AD and CGP identifiers of the user
$res = uldap_search('uni', "(&(objectClass=person)(uid=$id))", array('dn', 'cn', 'mail', 'homeDirectory'));
if ($res['code'] || $res['data']['count'] == 0) {
    echo(json_error(_T('User not found')));
    exit;
}
$msg = array();
$ue = uldap_pop($res);

// Delete the Unix user
$msg[] = 'group: '.uldap_value($ue, 'gidNumber');
$dn = uldap_dn($ue);
$res = uldap_delete('uni', "???".$dn."???");
if ($res['code'])
    $msg[] = _T('Error deleting Unix user "%s" (%s): %s', $id, $dn, $res['error']);

// Delete user from unix groups
$res = uldap_search('uni', "(&(objectClass=posixGroup)(memberUid=$id))", array('gidNumber'));
foreach (uldap_entries($res) as $ge) {
    $gidn = uldap_value($ge, 'gidNumber');
    //ldap_modify_unix_group('uni', $gidn, $id, 'remove');
    $msg[] = 'Sgrp: '.$gidn;
}

// Delete AD account
$cn = uldap_value($ue, 'cn');
if (!empty($cn) && !$servers['ads']['disable']) {
    $msg[] = "Deleting windows user: $cn";
    $res = uldap_search('ads', "(&(objectClass=user)(cn=$cn))", array('dn'));
    if ($res['code'] || $res['data']['count'] == 0) {
        $msg[] = _T('Windows user "%s" not found', $cn);
    } else {
        $we = uldap_pop($res);
        $wdn = uldap_dn($we);
        $res = uldap_delete('ads', $wdn);
        if ($res['code'])
            $msg[] = _T('Error deleting Windows user "%s" (%s): %s', $id, $wdn, $res['error']);
    }
}

// Delete CGP account
$mail = uldap_value($ue, "mail");
if (!empty($mail) && !$servers['cgp']['disable']) {
    $msg[] = "Deleting CGP user: $mail";
    $res = cgp_cmd('cgp', 'DeleteAccount', $mail);
    if ($res['code'])
        $msg[] = _T('Error deleting mail "%s" (%s): %s', $id, $mail, $res['error']);
}

// Delete user's home directory
$home = uldap_value($ue, 'homeDirectory');
if (!empty($home) && str2bool(get_config('remove_homes'))) {
    run_helper("delete", $home);
}

echo empty($msg) ? json_ok() : json_error($msg);
srv_disconnect_all();

?>
