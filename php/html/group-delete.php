<?php
// $Id$

// Delete group object

require '../lib/common.php';

send_headers();
$id = req_param('cn');
if (empty($id))  error_page("cn: required parameter missing");
if (is_reserved($id))  error_page("Cannot delete reserved object");

$res = uldap_search('uni', "(&(objectClass=posixGroup)(cn=$id))", array('dn'));
if (empty($res['data']))  error_page('Group not found');

$res = uldap_entry_delete('uni', uldap_dn(uldap_pop($res)));
echo($res['code'] ? json_error(_T('Error deleting group "%s": %s', $id, $res['error'])) : json_ok());
?>
