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

// Make sure this PHP install has gettext, we use it for language translation
if (! extension_loaded('gettext'))
	die('Your install of PHP appears to be missing GETTEXT support. GETTEXT is used for language translation. Please install GETTEXT support before using userman. (Dont forget to restart your web server afterwards)');

/* Helper functions.
 * Our required helper functions are defined in functions.php
 */
foreach ($pla_function_files as $file_name ) {
	if (! is_readable($file_name))
		pla_error(sprintf('Fatal error: Cannot read the file "%s", its permissions are too strict.',$file_name));
	ob_start();
	require $file_name;
	ob_end_clean();
}

// Configuration File check
if (! is_readable($config_file)) {
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.0//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic10.dtd">
<html>
<head>
  <title>userman</title>
  <link type="text/css" rel="stylesheet" href="css/style.css" />
</head>
<body>
  <h3 class="title">Configure userman</h3>
  <br /><br />
  <center>
    <?php printf(_('You need to configure userman. Edit the file "%s" to do so. An example config file is provided in "%s.example".'),$config_file,$config_file); ?>
  </center>
</body>
</html>
<?php
	die();
}

/*
 * Makes sure that the config file is properly setup and
 * that your install of PHP can handle LDAP stuff.
 */
function check_config() {
	global $config_file,$config;

	/* Check for syntax errors in config.php
	   As of php 4.3.5, this NO longer catches fatal errors :( */
	ob_start();
	include $config_file;
	$str = ob_get_contents();
	ob_end_clean();

	if ($str) {
		$str = strip_tags($str);
		$matches = array();
		preg_match('/(.*):\s+(.*):.*\s+on line (\d+)/',$str,$matches);
		$error_type = $matches[1];
		$error = $matches[2];
		$line_num = $matches[3];

		$file = file($config_file);
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.0//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic10.dtd">
<html>
<head>
  <title>Userman Config File Error</title>
  <link type="text/css" rel="stylesheet" href="css/style.css" />
</head>
<body>
  <h3 class="title">Config File ERROR</h3>
  <h3 class="subtitle"><?php printf('%s (%s) on line %s',$error_type,$error,$line_num); ?></h3>
  <center>
    <?php printf('Looks like your config file has an ERROR on line %s.<br />',$line_num) ?>
	Here is a snippet around that line <br />
    <br />
    <div style="text-align: left; font-family: monospace; margin-left: 80px; margin-right: 80px; border: 1px solid black; padding: 10px;">
    <?php
		for ($i = $line_num-9; $i<$line_num+5; $i++) {
			if ($i+1 == $line_num)
				echo '<div style="color:red;background:#fdd">';

			if ($i < 0)
				continue;

			printf('<b>%s</b>: %s<br />',$i+1,htmlspecialchars($file[$i]));

			if ($i+1 == $line_num)
				echo '</div>';
		}
    ?>
	</div>
    <br />
    Hint: Sometimes these errors are caused by lines <b>preceding</b> the line reported.
  </center>
</body>
</html>
<?php
		return false;
	}

	// Now read in config_default.php, which also reads in config.php
	require LIBDIR.'config_default.php';

	// Make sure this PHP install has all our required extensions
	if (! extension_loaded('ldap')) {
		pla_error('Your install of PHP appears to be missing LDAP support. Please install LDAP support before using userman. (Dont forget to restart your web server afterwards)');
		return false;
	}

	// Make sure that we have php-xml loaded.
	if (! function_exists('xml_parser_create')) {
		pla_error('Your install of PHP appears to be missing XML support. Please install XML support before using userman. (Dont forget to restart your web server afterwards)');
		return false;
	}

	// Make sure their session save path is writable, if they are using a file system session module, that is.
	if ( ! strcasecmp('Files', session_module_name() && ! is_writable(realpath(session_save_path())))) {
		pla_error('Your PHP session configuration is incorrect. Please check the value of session.save_path
			in your php.ini to ensure that the directory specified there exists and is writable.
			The current setting of "'.session_save_path().'" is un-writable by the web server.');
		return false;
	}

	if (! isset($ldapservers) || count($ldapservers->GetServerList()) == 0) {
		pla_error('Your config.php is missing Server Definitions.
			Please see the sample file config/config.php.example.',false);
		return false;
	}

	return true;
}

if (check_config()) { ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.0//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic10.dtd">
<html>
<head>
  <title>userman</title>
  <link rel="stylesheet" type="text/css" href="js/ext/resources/css/ext-all.css" />
  <script type="text/javascript" src="js/ext/adapter/ext/ext-base.js"></script>
  <script type="text/javascript" src="js/ext/ext-all.js"></script>
  <link rel="stylesheet" type="text/css" href="js/ext/examples/shared/examples.css" />
  <script type="text/javascript" src="js/main.js"></script>
</head>
<body>
  <h1>Hello World Window</h1>
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
<?php } ?>

