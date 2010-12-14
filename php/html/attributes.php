<?php
// $Id$

// Return translations

require '../lib/common.php';

send_json_headers();
echo 'var all_attrs = ' . json_encode($all_attrs) . ';';
?>
