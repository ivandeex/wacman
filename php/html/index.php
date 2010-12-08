<?php
// $Id$

// Sanity checking
define('LIBDIR','../lib/');
ini_set('display_errors',1);
error_reporting(E_ALL);

// General functions needed to proceed.
ob_start();
if (! is_readable(LIBDIR.'common.php')) {
	ob_end_clean();
	die("Fatal error: cannot read 'common.php'");
}
require LIBDIR.'common.php';
ob_end_clean();
// Start the show!
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.0//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic10.dtd">
<html>
<head>
  <title>Userman</title>
  <link rel="stylesheet" type="text/css" href="js/ext/resources/css/ext-all.css" />
  <script type="text/javascript" src="js/ext/adapter/ext/ext-base.js"></script>
  <script type="text/javascript" src="js/ext/ext-all.js"></script>
  <script type="text/javascript" src="js/main.js"></script>
</head>
<body>
  <h1>Userman</h1>
  <input type="button" id="show-btn" value="Hello World" />
  <div id="hello-win" class="x-hidden">
    <div class="x-window-header">Hello Dialog</div>
    <div id="hello-tabs">
        <div class="x-tab" title="Hello World 1">
            <p>Hello...</p>
        </div>
        <div class="x-tab" title="Hello World 2">
            <p>... World!</p>
        </div>
    </div>
  </div>
</body>
</html>

