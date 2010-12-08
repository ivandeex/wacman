<?php
// $Id$

// Sanity checking
define('LIBDIR','../lib/');
ini_set('display_errors',1);
error_reporting(E_ALL);

// General functions needed to proceed.
ob_start();
if (! is_readable(LIBDIR.'functions.php')) {
	ob_end_clean();
	die("Fatal error: cannot read 'functions.php'");
}
require LIBDIR.'functions.php';
$config_file = CONFDIR.'config.php';
ob_end_clean();

// Verify that this PHP install has gettext
if (! extension_loaded('gettext')) {
	pla_error("Your install of PHP appears to be missing GETTEXT support.");
	die();
}

// Helper functions defined in functions.php
foreach ($pla_function_files as $file) {
	if (! is_readable($file))
		pla_error("Fatal error: Cannot read the file \"$file\"");
	ob_start();
	require $file;
	ob_end_clean();
}

// Make sure this PHP install has LDAP extension
if (! extension_loaded('ldap')) {
	pla_error("Your install of PHP appears to be missing LDAP support.");
	die();
}

// Make sure that we have php-xml loaded.
if (! function_exists('xml_parser_create')) {
	pla_error("Your install of PHP appears to be missing XML support");
	die();
}

// Configuration File check
if (! is_readable($config_file)) {
    pla_error("Fatal error: Cannot read the file \"$config_file\"");
    die();
}

// Verify that the config file is properly setup
ob_start();
include $config_file;
$str = ob_get_contents();
ob_end_clean();
if ($str) {
	$str = strip_tags($str);
	pla_error("Your config file has an error: $str");
	die();
}

// Now read in config_default.php, which also reads in config.php
require LIBDIR.'config_default.php';

// Make sure their session save path is writable, if they are using a file system session module, that is.
if ( ! strcasecmp('Files', session_module_name() && ! is_writable(realpath(session_save_path())))) {
	pla_error('Your PHP session configuration is incorrect. Please check the value of session.save_path
		in your php.ini, the current setting of "'.session_save_path().'" is not writable.');
	die();
}

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

