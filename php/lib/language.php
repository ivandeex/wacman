<?php
// $Id$

// Language configuration. Auto or specified.

header('Content-type: text/html; charset=UTF-8', true);

$translations = array();
$ext_js_lang = null;

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

    if ($language != 'en') {
        global $ext_js_lang;
        $ext_js_lang = get_config('ext_js_lang', null);
        if ($ext_js_lang)
            $ext_js_lang = sprintf($ext_js_lang, $language);
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
