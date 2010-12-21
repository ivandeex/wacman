<?php
// $Id$

// Syslog logging.

define_syslog_variables();
openlog('userman', LOG_ODELAY, LOG_DAEMON);

$last_error = '';

function get_error () {
    global $last_error;
    return $last_error;
}

function set_error ($message = '') {
    global $last_error;
    $last_error = $message;
}

function log_msg () {
    static $level_str = array(
        LOG_ERR => 'error', LOG_WARNING => 'warning', LOG_INFO => 'info',
        LOG_NOTICE => 'notice', LOG_DEBUG => 'debug'
        );
    $args = func_get_args();
    $level = array_shift($args);
    if (($level == LOG_DEBUG || $level == LOG_NOTICE) && !get_config('debug'))
        return false;
    if (count($args) == 1 && is_array($args[0]))
        $args = $args[0];
    $format = array_shift($args);
    $message = _T($format, $args);
    static $no = 100;
    syslog(LOG_INFO, ''.++$no.' ['.$level_str[$level].'] '.$message);
    if ($level == LOG_ERR)
        set_error($message);
    return true;
}

function log_err()    { $args = func_get_args(); return log_msg(LOG_ERR,     $args); }
function log_error()  { $args = func_get_args(); return log_msg(LOG_ERR,     $args); }
function log_warn()   { $args = func_get_args(); return log_msg(LOG_WARNING, $args); }
function log_info()   { $args = func_get_args(); return log_msg(LOG_INFO,    $args); }
function log_notice() { $args = func_get_args(); return log_msg(LOG_NOTICE,  $args); }
function log_debug()  { $args = func_get_args(); return log_msg(LOG_DEBUG,   $args); }

?>
