<?php
// $Id$

// Delete group object

require '../lib/common.php';

send_json_headers();
$id = nvl(isset($_GET['cn']) ? $_GET['cn'] : '');
if (empty($id)) {
    echo json_error("cn: required parameter missing");
    exit;
}
if (is_reserved($id)) {
    echo json_error("Cannot delete reserved object");
    exit;
}
$res = uldap_search('uni', "(&(objectClass=posixGroup)(cn=$id))", array('dn'));
if ($res['code'] || $res['data']['count'] == 0) {
    echo(json_error(_T('Group not found')));
    exit;
}
$dn = uldap_dn(uldap_pop($res));
$res = uldap_delete('uni', $dn);
if ($res['code']) {
    echo(json_error(_T('Error deleting group "%s": %s', $id, $res['error'])));
    exit;
}
echo(json_ok());
srv_disconnect_all();

?>
