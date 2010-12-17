<?php
// $Id$

// Language configuration. Auto or specified.

header('Content-type: text/html; charset=UTF-8', true);

$translations = array();

function setup_language () {
    global $config;
    $language = get_config('language', 'en');

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

    $filename = realpath(LIBDIR . 'lang_' . $language . '.php');
    if (is_readable($filename)) {
        global $translations;
        require($filename);
        log_debug("%s: %s translations loaded", $filename, count($translations));
    } else {
        log_error("%s: cannot read translation file", $filename);
    }
}

function _T () {
	global $translations;
	$args = func_get_args();
	$format = array_shift($args);
	if (count($args) == 1 && is_array($args[0]))
	    $args = $args[0];
	if (isset($translations[$format]))
	    $format = $translations[$format];
	$message = empty($args) ? $format : vsprintf($format, $args);
	return $message;
}

?>
