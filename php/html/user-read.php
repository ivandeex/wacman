<?php
// $Id$

// Retrieve user object

require '../lib/common.php';

send_headers();
$id = req_param('id');
if (empty($id))  error_page("id is missing");

$usr = create_obj('user');

foreach (array('uni','ads','cgp') as $srv) {
    if ($servers[$srv]['disable'])  continue;
    $msg = obj_read($usr, $srv, $id);
    if (! $msg)  continue;
    if ($srv == 'uni')  error_page($msg);
    log_info('will create "%s" user for uid "%s"', $srv, $id);
}

echo(obj_json_encode($usr));
?>
