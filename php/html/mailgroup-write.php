<?php
// $Id$

// Retrieve mail group object

require '../lib/common.php';

send_json_headers();
uldap_connect_all();
echo obj_json_error('mailgroup test error');
uldap_disconnect_all();

?>
