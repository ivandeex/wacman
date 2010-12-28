<?php
// $Id$

// Return translations

require '../lib/common.php';

send_json_headers();
echo "Userman.translations = " . json_encode($translations) . ";\n";
echo "Userman.config = " . json_encode($config) . ";\n";
echo "Userman.all_attrs = " . json_encode($all_attrs) . ";\n";
echo "Userman.gui_attrs = " . json_encode($gui_attrs) . ";\n";

?>
