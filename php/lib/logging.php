<?php
// $Id$

// Syslog logging.

define_syslog_variables();
openlog('userman', LOG_ODELAY, LOG_DAEMON);

function log_msg () {
    static $level_str = array(
        LOG_ERR => 'error', LOG_WARNING => 'warning', LOG_INFO => 'info',
        LOG_NOTICE => 'notice', LOG_DEBUG => 'debug'
        );
    $args = func_get_args();
    $level = array_shift($args);
    if (count($args) == 1 && is_array($args[0]))
        $args = $args[0];
    $format = array_shift($args);
    $message = _T($format, $args);
    syslog($level, '['.$level_str[$level].'] '.$message);
    return true;
}

function log_err()    { $args = func_get_args(); return log_msg(LOG_ERR,     $args); }
function log_warn()   { $args = func_get_args(); return log_msg(LOG_WARNING, $args); }
function log_info()   { $args = func_get_args(); return log_msg(LOG_INFO,    $args); }
function log_notice() { $args = func_get_args(); return log_msg(LOG_NOTICE,  $args); }
function log_debug()  { $args = func_get_args(); return log_msg(LOG_DEBUG,   $args); }

?>
