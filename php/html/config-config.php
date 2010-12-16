<?php
// $Id$

// Return translations

require '../lib/common.php';

send_json_headers();
echo "var translations = " . json_encode($translations) . ";\n";
echo "var config = " . json_encode($config) . ";\n";
echo "var all_attrs = " . json_encode($all_attrs) . ";\n";
echo "var gui_attrs = " . json_encode($gui_attrs) . ";\n";
?>
