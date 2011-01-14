<?php
// $Id$


////////////////////////////////////////////////////////
//       Attribute initializer
//

function setup_all_attrs () {

    global $all_attrs;
    global $gui_attrs;
    global $data_accessors;
    global $data_converters;
    global $servers;
    global $config;

    foreach ($all_attrs as $objtype => &$descs) {

        foreach ($servers as $srv => &$cfg) {
            $cfg['attrhash'] = array();
            $cfg['attrhash'][$objtype] = array();
        }

        foreach ($descs as $name => &$desc) {

            if ($name == '_accessors')
                continue;   // it's an accessor descriptor
            // others are attribute descriptors

            $desc['name'] = $name;
            $desc['visual'] = false;

            // substitute in default values
            if (empty($desc['type']))  $desc['type'] = 'string';
            if (isset($desc['label']))  $desc['label'] = _T($desc['label']);
            if (! isset($desc['readonly']))  $desc['readonly'] = false;
            if (! isset($desc['verify']))  $desc['verify'] = false;
            if (! isset($desc['colwidth']))  $desc['colwidth'] = null;
            if (! isset($desc['popup']))  $desc['popup'] = null;
            if (! isset($desc['checkbox']))  $desc['checkbox'] = false;
            if ($desc['checkbox'])  $desc['popup'] = 'yesno';

            // attributes can have a default value
            if (! isset($desc['defval'])) {
                $cfg_def = "default_value_${objtype}_${name}";
                $desc['defval'] = isset($config[$cfg_def]) ? $config[$cfg_def] : null;
            }

            // attributes can be automatically copied from other attributes
            if (isset($desc['copyfrom']) && !isset($descs[$desc['copyfrom']]))
                log_error('%s attribute "%s" is copy-from unknown "%s"',
                            $objtype, $name, $desc['copyfrom']);
            if (! isset($desc['copyfrom']))  $desc['copyfrom'] = null;

            // setup data conversions
            if (! isset($desc['conv']))  $desc['conv'] = 'none';
            foreach (array(0,1) as $dir) {
                $sub = isset($data_converters[$desc['conv']]) ? $data_converters[$desc['conv']][$dir] : null;
                if (empty($sub))  $sub = 'conv_none';
                $desc[$dir ? 'disp2attr' : 'attr2disp'] = $sub;
            }

            // parse and setup per-server mappings for the attribute
            $ldap = isset($desc['ldap']) ? $desc['ldap'] : '';
            if (! is_array($ldap)) {
                $arr = split_list($ldap);
                $ldap = array();
                foreach ($arr as $x)  $ldap[$x] = '';
            }

            foreach (array_keys($ldap) as $srv) {

                // 'ntuser' is a special set of unix attributes
                // they can be either supported as 'uni' or unsupported
                if ($srv == 'ntuser') {
                    if (get_config('ntuser_support', false)) {
                        $ldap[$srv = 'uni'] = $ldap['ntuser'];
                        unset($ldap['ntuser']);
                    } else {
                        unset($ldap['ntuser']);
                        continue;
                    }
                }

                if (! isset($servers[$srv])) {
                    log_error('wrong server "%s" in objtype "%s" descriptor "%s"',
                                print_r($srv, 1), $objtype, $name);
                    continue;
                }

                if (empty($ldap[$srv]))
                    $ldap[$srv] = $name;

                $ldap_attr = $ldap[$srv];
				$cfg =& $servers[$srv];
                if (isset($cfg['attrhash'][$objtype][$ldap_attr])) {
                    if (! empty($desc['is_duplicate']))
                        log_error('duplicate attribute "%s" as "%s" for server "%s"',
                                    $name, $ldap_attr, $srv);
                } else if (empty($ldap['disable'])) {
                    $cfg['attrhash'][$objtype][$ldap_attr] = 1;
                }
            }

            $desc['ldap'] = $ldap;

            // disable attributes without servers or due to configuration
            if (! isset($desc['disable']))  $desc['disable'] = false;
            if (! attribute_enabled($objtype, $name))  $desc['disable'] = true;
            if (empty($ldap))  $desc['disable'] = true;

            // setup readers and writers
            if ($desc['disable'])
                $subs = $data_accessors['none'];
            else if (is_array($desc['type']))
                $subs = $desc['type'];
            else
                $subs = $data_accessors[ $desc['type'] ];
            if (!is_array($subs))
                error_page(_T('type "%s" of "%s" attribute "%s" is not supported',
                                $desc['type'], $objtype, $name));
            $desc['ldap_read'] = $subs[0] ? $subs[0] : 'ldap_read_none';
            $desc['ldap_write'] = $subs[1] ? $subs[1] : 'ldap_write_none';
            $desc['ldap_write_final'] = $subs[2] ? $subs[2] : 'ldap_write_none';
        }

        foreach ($servers as $srv => &$cfg) {
            $arr = array_keys($cfg['attrhash'][$objtype]);
            sort($arr);
            $cfg['attrlist'][$objtype] = $arr;
            unset($cfg['attrhash']);
        }
    }

    // mark visual attributes
    foreach ($gui_attrs as $objtype => &$obj_gui) {
        foreach ($obj_gui as &$gui_tab) {
            foreach ($gui_tab[1] as $name) {
                if (isset($all_attrs[$objtype][$name])) {
                    $all_attrs[$objtype][$name]['visual'] = true;
                } else {
                    log_error('cannot mark attribute "%s" in object "%s" as visual',
                                $name, $objtype);
                }
            }
        }
    }

    // all done.
}


////////////////////////////////////////////////////////
//       Objects
//

function & create_obj ($objtype) {
    global $all_attrs;
    global $servers;

    if (! isset($all_attrs[$objtype]))
        log_error('unknown object type "%s"', $objtype);

    $obj = array(
        'type' => $objtype,
        'changed' => false,
        'renamed' => false,
        'attrs' => array(),
        'ldap' => array(),
        'attrlist' => array(),
        '_accessors' => array(),
        );

    foreach ($all_attrs[$objtype] as $name => &$desc) {
        if ($name == '_accessors') {
            // accessor descriptor
            $obj[$name] = $desc;
            continue;
        }
        // others are attribute descriptors
        $obj['attrs'][$name] = array(
            'name'  => $name,
            'type'  => $desc['type'],
            'desc'  => &$desc,
            'ldap'  => array(),
            'val'   => '',
            'dirty' => false,
        );
    }

    foreach (array_keys($servers) as $srv) {
        $obj['attrlist'][$srv] =& $servers[$srv]['attrlist'][$objtype];
        $obj['ldap'][$srv] = array();
    }

    return $obj;
}


//
// Fetch object values from CGP/LDAP server
//
function obj_read (&$obj, $srv, $id) {
    global $servers;

    $obj['idold'] = null;
    $obj['id'] = $id;
    $obj['ldap'][$srv] = array();
    $obj['msg'] = '';

    if ($servers[$srv]['disable'])  return null;

    $reader = @$obj['_accessors'][$srv]['read'];
    if (is_null($reader))
        error_page(_T('Reader not defined for "%s" on server "%s"', $obj['type'], $srv));

    if (is_array($reader)) {
        // Read the object using LDAP
        $filter = _array_to_filter($reader, $obj);
        $res = uldap_search($srv, $filter, $obj['attrlist'][$srv]);
    }
    else {
        // Read the object using a custom function
        $filter = $reader . "()";
        $res = $reader($obj, $srv, $id);
    }

    $obj['ldap'][$srv] = uldap_pop($res);
    if (empty($res['data'])) {
        log_debug('obj_read(%s) [%s]: failed with "%s"',
                    $srv, $filter, $res['error']);
        $obj['msg'] = $res['error'] ? $res['error'] : 'not found';
    }
    if ($obj['msg'])  error_page($obj['msg']);
    $ldap =& $obj['ldap'][$srv];

    foreach ($obj['attrs'] as $attr_name => &$at) {
        if (! isset($at['desc']['ldap'][$srv])) // attribute exists for this server?
            continue;
        $read_func = $at['desc']['ldap_read'];
        $ldap_name = $at['desc']['ldap'][$srv];
        $val = nvl($read_func($obj, $at, $srv, $ldap, $ldap_name));
        // FIXME: use NULL as a "don't change" mark
        if (!empty($val))  $at['val'] = $val;
    }

    return '';
}


//
// Send object values to LDAP/CGP server
//
function obj_write (&$obj, $srv, $id, $idold) {
    global $servers;

    if ($servers[$srv]['disable'])  return null;

    $writer = @$obj['_accessors'][$srv]['write'];
    if (is_null($writer))
        error_page(_T('Writer not defined for "%s" on server "%s"', $obj['type'], $srv));

    log_debug('start writing to "%s"...', $srv);

    // Prepare writing parameters
    $obj['idold'] = $idold;
    $obj['id'] = $id;
    $obj['renamed'] = false;    // can be set to true by subordinate writes
    $ldap =& $obj['ldap'][$srv];
    $changed = false;
    $msg = null;

    // Find new DN
    if (is_array($writer)) {
        $dn_old = uldap_dn($ldap);
        $dn = get_attr($obj, 'dn');
        if (empty($dn) || (!empty($idold) && empty($dn_old)))
            return _T("DN is missing");
    }

    // Convert object attributes into low-level values
    foreach ($obj['attrs'] as $attr_name => &$at) {
        if (! isset($at['desc']['ldap'][$srv]))
            continue;

        // If we used call_user_func(), all parameters would be passed by value,
        // and the "renamed" magic would not work.
        //
        // If we used call_user_func_array(), we would need to mark
        // all passed by reference parameters by "&" in the call time array.
        //
        // The variable function used here honors pass by reference
        // in function prototypes (at least in PHP 5.2.16).
        $write_func = $at['desc']['ldap_write'];
        $ldap_name = $at['desc']['ldap'][$srv];
        if ($write_func($obj, $at, $srv, $ldap, $ldap_name, nvl($at['val'])))
            $changed = $obj['changed'] = true;
	}

    // Rename LDAP object if needed
    if (is_array($writer) && !empty($idold) && $id != $idold) {
        $rdn_new = dn_to_rdn($dn);
        $res = uldap_entry_rename($srv, $dn_old, $rdn_new);
        if ($res['code']) {
            $msg = _T('Cannot rename %s "%s" to "%s": %s',
                        $obj['type'], $obj['idold'], $obj['id'], $res['error']);
        } else {
            log_debug("rename %s DN=[%s] to RDN=[%s] OK", $obj['type'], $dn_old, $rdn_new);
            $obj['renamed'] = true;
        }
    }

    if ($msg)  return $msg;

    // Update object attributes
    if ($changed || empty($idold)) {
        // Either changed during update or creating a new record.
        // As usual, array means LDAP and string means a function.
        if (is_array($writer)) {
            uldap_set_dn($ldap, null);
            // Empty $idold means a brand new record
            if (empty($idold))
                $res = uldap_entry_create($srv, $dn, $ldap);
            else
                $res = uldap_entry_update($srv, $dn, $ldap);
        } else {
            $res = $writer($obj, $srv, $id, $idold, $ldap);
        }
        log_debug('writing to "%s" returns "%s"', $srv, $res['error']);
        // Note: code 82 = `no values to update'
        if ($res['code'] && $res['code'] != 82)
            $msg = $res['error'];
    } else {
        // Not changed and not creating.
        log_debug('nothing to write to "%s"', $srv);
    }

    if ($msg)  return $msg;

    // Perform post-update operations
    foreach ($obj['attrs'] as $attr_name => &$at) {
        if (! isset($at['desc']['ldap'][$srv]))
            continue;
        $post_func = $at['desc']['ldap_write_final'];
        $ldap_name = $at['desc']['ldap'][$srv];
        if ($post_func($obj, $at, $srv, $ldap, $ldap_name, nvl($at['val'])))
            $changed = $obj['changed'] = true;
    }

    return $msg;
}


//
// Return list of objects
//
function obj_list ($objtype, $srv) {
    global $all_attrs;

    // Get the listing function or LDAP search filter
    $lister = @$all_attrs[$objtype]['_accessors'][$srv]['list'];
    if (is_null($lister))
        error_page(_T('Lister not defined for "%s" on server "%s"', $obj_type, $srv));

    // Get the list of attributes to get, the first one will be sort key
    $attrs = array();
    foreach ($all_attrs[$objtype] as $name => &$desc) {
        if (isset($desc['colwidth']))  $attrs[] = $name;
    }

    // Fetch the list
    if (is_array($lister)) {
        $filter = _array_to_filter($lister);
        $res = uldap_search($srv, $filter, $attrs);
    } else {
        $filter = $lister . "()";
        $res = $lister($srv);
    }

    // Sort the list by the first attribute found
    if (!$res['code']) {
        global $_list_sort_key;
        $_list_sort_key = $attrs[0];
        usort($res['data'], '_obj_list_sort');
    }

    return $res;
}

$_list_sort_key = '';
function _obj_list_sort ($a, $b) {
    global $_list_sort_key;
    return strcmp ($a[$_list_sort_key], $b[$_list_sort_key]);
}


//
// Helper function that creates filter strings from arrays
//
function _array_to_filter($array, $obj = null) {
    $filter = "";

    foreach ($array as $name => $val) {
        if ($val === '$_ID')
            $val = $obj['id'];
        else if (is_string($val) && $val[0] == '$')
            $val = get_attr($obj, substr($val, 1));
        $filter .= "(" . $name . "=" . $val . ")";
    }

    if (count($array) > 1)
        $filter = "(&"  . $filter . ")";
    return $filter;
}


////////////////////////////////////////////////////////
//       Attribute helpers
//


function get_attr (&$obj, $name, $param = array()) {
    if (!isset($obj['attrs'][$name])) {
        log_error('get_attr: attribute "%s" undefined in object "%s"', $name, $obj['type']);
        return '';
    }
    return nvl($obj['attrs'][$name]['val']);
}


function set_attr (&$obj, $name, $val) {
    if (!isset($obj['attrs'][$name]))
        log_error('set_attr: attribute "%s" undefined in object "%s"', $name, $obj['type']);
    else
        $obj['attrs'][$name]['val'] = $val;
}


//
// Update object values from web request
//
function obj_update (&$obj) {
    foreach ($obj['attrs'] as $name => &$at) {
        if (req_exists($name)) {
            $at['val'] = req_param($name);
            $at['dirty'] = true;
        }
    }
}


function obj_json_encode (&$obj) {
    $ret = array();
    foreach ($obj['attrs'] as $name => &$at)  $ret[$name] = $at['val'];
    return json_ok($ret);
}

?>
