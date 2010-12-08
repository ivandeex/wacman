<?php
// $Id$

/**
 * Contains code to be executed at the top of each phpLDAPadmin page.
 * include this file at the top of every PHP file.
 *
 * This file will "pre-initialise" a PLA environment so that any PHP file will have a consistent
 * environment with other PLA PHP files.
 *
 * This code WILL NOT check that all required functions are usable/readable, etc. This process has
 * been moved to index.php (which really is only called once when a browser hits PLA for the first time).
 *
 * The list of ADDITIONAL function files is now defined in functions.php.
 *
 * @package phpLDAPadmin
 */

@define('LIBDIR','../lib/');

// For PHP5 backward/forward compatibility
if (! defined('E_STRICT'))
	define('E_STRICT',2048);

// General functions needed to proceed.
ob_start();
require_once realpath(LIBDIR.'functions.php');
ob_end_clean();

// Turn on all notices and warnings. This helps us write cleaner code (we hope at least)
if (phpversion() < 5)
	pla_error('Sorry, PLA is a PHP5 application.');

// Verify that this PHP install has gettext
if (! extension_loaded('gettext'))
	pla_error("Your install of PHP appears to be missing GETTEXT support.");

// Our error handler receives all error notices that pass the error_reporting() level set above.
set_error_handler('pla_error_handler');
// Disable error reporting until all our required functions are loaded.
error_reporting(0);

// Helper functions defined in functions.php
ob_start();
foreach ($pla_function_files as $file) {
	if (! is_readable($file))
		pla_error("Fatal error: Cannot read the file \"$file\"");
	ob_start();
	require_once realpath ($file);
	ob_end_clean();
}

// Make sure this PHP install has LDAP extension
if (! extension_loaded('ldap'))
	pla_error("Your install of PHP appears to be missing LDAP support.");

// Make sure that we have php-xml loaded.
if (! function_exists('xml_parser_create'))
	pla_error("Your install of PHP appears to be missing XML support");

// Configuration File check
$config_file = CONFDIR.'config.php';
if (! is_readable($config_file))
    pla_error("Fatal error: Cannot read the file \"$config_file\"");

// Now read in config_default.php, which also reads in config.php
require_once realpath(LIBDIR.'config_default.php');

// Make sure their session save path is writable, if they are using a file system session module, that is.
if ( ! strcasecmp('Files', session_module_name() && ! is_writable(realpath(session_save_path()))))
	pla_error('Your PHP session configuration is incorrect. Please check the value of session.save_path
		in your php.ini, the current setting of "'.session_save_path().'" is not writable.');

// We are now ready for error reporting.
error_reporting(E_DEBUG);

// At this point we have read all our additional function PHP files and our configuration.

// Check our custom variables.
#$config->CheckCustom();

#if (pla_session_start())
#	run_hook('post_session_init',array());

// Language configuration. Auto or specified.

$language = $config->GetValue('appearance','language');

if ($language == 'auto') {
	// Make sure their browser correctly reports language. If not, skip this.
	if (isset($_SERVER['HTTP_ACCEPT_LANGUAGE'])) {
		$langs = preg_split ('/[;,]+/', $_SERVER['HTTP_ACCEPT_LANGUAGE']);
		foreach ($langs as $key => $value) {
			$value = preg_split('/[-]+/',$value);
			$value = strtolower(substr($value[0],0,2));
			if ($value == 'q=')
				unset($langs[$key]);
			else
				$langs[$key] = $value;
		}
		$langs = array_unique($langs);
	}
    // FIXME...
    $language = 'en';
}

header('Content-type: text/html; charset=UTF-8', true);

require_once realpath(LIBDIR.'translations.php');

// Strip slashes from GET, POST, and COOKIE variables if this
// PHP install is configured to automatically addslashes()
if (get_magic_quotes_gpc() && (! isset($slashes_stripped) || ! $slashes_stripped)) {
	array_stripslashes($_REQUEST);
	array_stripslashes($_GET);
	array_stripslashes($_POST);
	array_stripslashes($_COOKIE);
	$slashes_stripped = true;
}

?>
