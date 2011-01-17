<?php
// $Id$

// Delete user object

require '../lib/common.php';

send_headers();
$id = req_param('uid');
if (empty($id))  error_page("uid: required parameter wrong or not specified");
if (is_reserved($id))  error_page("Cannot delete reserved object");

// Find Unix, AD and CGP identifiers of the user
$srv = 'uni';
$res = uldap_search($srv, "(&(objectClass=person)(uid=$id))", array('dn', 'cn', 'mail', 'homeDirectory'));
if (empty($res['data']))  error_page('User not found');
$msg = array();
$ue = uldap_pop($res);

// Delete the Unix user
$dn = uldap_dn($ue);
$res = uldap_entry_delete($srv, $dn);
if ($res['code'])
    $msg[] = _T('Error deleting Unix user "%s" (%s): %s', $id, $dn, $res['error']);

// Delete user from unix groups
$dummy_usr = create_obj('user');
$res = uldap_search($srv, "(&(objectClass=posixGroup)(memberUid=$id))", array('gidNumber'));
foreach (uldap_entries($res) as $ge) {
    $gidn = uldap_value($ge, 'gidNumber');
    modify_unix_group($dummy_usr, $srv, $gidn, $id, false);
}
foreach ($dummy_usr['msg'] as $line)  $msg[] = $line;

// Delete AD account
$cn = uldap_value($ue, 'cn');
if (!empty($cn) && !$servers['ads']['disable']) {
    $res = uldap_search('ads', "(&(objectClass=user)(cn=$cn))", array('dn'));
    if (empty($res['data'])) {
        $msg[] = _T('Windows user "%s" not found', $cn);
    } else {
        $we = uldap_pop($res);
        $wdn = uldap_dn($we);
        $res = uldap_entry_delete('ads', $wdn);
        if ($res['code'])
            $msg[] = _T('Error deleting Windows user "%s" (%s): %s', $id, $wdn, $res['error']);
    }
}

// Delete CGP account
$mail = uldap_value($ue, "mail");
if (!empty($mail) && !$servers['cgp']['disable']) {
    $res = cgp_cmd('cgp', 'DeleteAccount', $mail);
    if ($res['code'])
        $msg[] = _T('Error deleting mail "%s" (%s): %s', $id, $mail, $res['error']);
}

// Delete user's home directory
$home = uldap_value($ue, 'homeDirectory');
if (!empty($home) && str2bool(get_config('remove_homes'))) {
    run_helper("delete", $home);
}

echo(empty($msg) ? json_ok() : json_error($msg));
?>
