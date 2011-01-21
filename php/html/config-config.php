<?php
// $Id$

// Return translations

require '../lib/common.php';

send_headers();
echo("Wacman.translations = " . json_encode($translations) . ";\n");
echo("Wacman.config = " . json_encode($config) . ";\n");
echo("Wacman.all_attrs = " . json_encode($all_attrs) . ";\n");
echo("Wacman.gui_attrs = " . json_encode($gui_attrs) . ";\n");

?>
