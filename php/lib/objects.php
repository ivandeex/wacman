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
            if (! isset($desc['colwidth']))  $desc['colwidth'] = null;
            if (! isset($desc['popup']))  $desc['popup'] = null;
            if (! isset($desc['checkbox']))  $desc['checkbox'] = false;
            if (! isset($desc['srv']))  $desc['srv'] = '';
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

            // disable attributes due to configuration
            if (! isset($desc['disable']))  $desc['disable'] = false;
            if (! attribute_enabled($objtype, $name))  $desc['disable'] = true;

            // parse and setup per-server mappings for the attribute
            if (! is_array($desc['srv'])) {
                // if all server attributes have the same name
                // as the main attribute, we can use a simple string
                // with server names separated by commas
                $arr = split_list($desc['srv']);
                $desc['srv'] = array();
                foreach ($arr as $x)  $desc['srv'][$x] = '';
            }

            foreach (array_keys($desc['srv']) as $srv) {

                // 'ntuser' is a special set of unix attributes
                // they can be either supported as 'uni' or unsupported
                if ($srv == 'ntuser') {
                    if (get_config('ntuser_support', false)) {
                        $desc['srv']['uni'] = $desc['srv']['ntuser'];
                        $srv = 'uni';
                        unset($desc['srv']['ntuser']);
                    } else {
                        unset($desc['srv']['ntuser']);
                        continue;
                    }
                }

                // having gotten rid of virtual servers,
                // now check if the server exists
                if (! isset($servers[$srv]))
                    error_page(_T('wrong server "%s" in objtype "%s" descriptor "%s"',
                                print_r($srv, 1), $objtype, $name));

                // skip attribute mapping if server is disabled
                $cfg =& $servers[$srv];
                if ($cfg['disable'])  {
                    unset($desc['srv'][$srv]);
                    continue;
                }

                // user can omit a server attribute name
                // if it coinsides with the main field name.
                if (empty($desc['srv'][$srv]))
                    $desc['srv'][$srv] = $name;

                // check that attribute mappings to servers
                // do not duplicate each other
                $ldap_attr = $desc['srv'][$srv];
                if (isset($cfg['attrhash'][$objtype][$ldap_attr])) {
                    if (! empty($desc['is_duplicate']))
                        log_error('duplicate attribute "%s" as "%s" for server "%s"',
                                    $name, $ldap_attr, $srv);
                    continue;
                }
                if (!isset($desc['disable']) || empty($desc['disable']))
                    $cfg['attrhash'][$objtype][$ldap_attr] = 1;
            }

            // disable attributes without server mappings
            if (empty($desc['srv']))  $desc['disable'] = true;

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


//
// Object constructor
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
        'data' => array(),
        'attrlist' => array(),
        '_accessors' => array(),
        'msg' => array(),
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
            'srv'  => array(),
            'val'   => '',
            'dirty' => false,
        );
    }

    foreach (array_keys($servers) as $srv) {
        $obj['attrlist'][$srv] =& $servers[$srv]['attrlist'][$objtype];
        $obj['data'][$srv] = array();

        $cleaner = @$obj['_accessors'][$srv]['clean'];
        if ($cleaner)
            $cleaner($obj, $srv, $obj['data'][$srv]);
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

    if ($servers[$srv]['disable'])  return null;

    $reader = @$obj['_accessors'][$srv]['read'];
    if (is_null($reader))
        error_page(_T('reader not defined for "%s" on server "%s"', $obj['type'], $srv));

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

    if (empty($res['data'])) {
        log_debug('obj_read(%s) [%s]: failed with "%s"',
                    $srv, $filter, $res['error']);
        $obj['msg'][] = $res['error'] ? $res['error'] : 'not found';
    }

    if ($obj['msg'])  return $obj['msg'];

    $obj['data'][$srv] = uldap_pop($res);
    $data =& $obj['data'][$srv];

    foreach ($obj['attrs'] as $attr_name => &$at) {
        if (! isset($at['desc']['srv'][$srv])) // attribute exists for this server?
            continue;
        $read_func = $at['desc']['ldap_read'];
        $ldap_attr = $at['desc']['srv'][$srv];
        $val = nvl($read_func($obj, $at, $srv, $data, $ldap_attr));
        // FIXME: use NULL as a "don't change" mark
        if (empty($at['val']) && !empty($val))
            $at['val'] = $val;
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

    log_debug('obj_write(%s,%s,%s) begin', $srv, $id, $idold);

    // Prepare writing parameters
    $obj['idold'] = $idold;
    $obj['id'] = $id;
    $data =& $obj['data'][$srv];
    $changed = false;

    $dn_old = uldap_dn($data);
    if (is_array($writer) && !empty($idold) && empty($dn_old)) {
        log_info('old DN is missing when writing to server "%s". will create.', $srv);
        $idold = null;
    }

    // Convert object attributes into low-level values
    foreach ($obj['attrs'] as $attr_name => &$at) {
        if (! isset($at['desc']['srv'][$srv]) || $at['desc']['readonly'])
            continue;

        //
        // If we used call_user_func(), all parameters would be passed by value,
        // and the "renamed" magic would not work.
        //
        // If we used call_user_func_array(), we would need to mark
        // all passed by reference parameters by "&" in the call time array.
        //
        // The variable function used here honors pass by reference
        // in function prototypes (at least in PHP 5.2.16).
        //
        $write_func = $at['desc']['ldap_write'];
        $ldap_attr = $at['desc']['srv'][$srv];
        $retval = $write_func($obj, $at, $srv, $data, $ldap_attr, nvl($at['val']));
        if ($retval)  $changed = $obj['changed'] = true;
    }

    $dn = uldap_dn($data);
    if (is_array($writer) && empty($dn))
        return log_error('new DN is missing when writing to server "%s"', $srv);

    // Rename LDAP object if needed
    if (is_array($writer) && !empty($idold) && $id != $idold) {
        $rdn_new = dn_to_rdn($dn);
        $res = uldap_entry_rename($srv, $dn_old, $rdn_new);
        if ($res['code']) {
            $obj['msg'][] = _T('Cannot rename %s "%s" to "%s": %s',
                                $obj['type'], $obj['idold'], $obj['id'], $res['error']);
        } else {
            log_debug("rename %s DN=[%s] to RDN=[%s] OK", $obj['type'], $dn_old, $rdn_new);
            $obj['renamed'] = true;
        }
    }

    if ($obj['msg'])  return $obj['msg'];

    // DN is passed to the updating routine directly
    uldap_set_dn($data, null);

    // Let one mangle the data structure as desired.
    $prewriter = @$obj['_accessors'][$srv]['prewrite'];
    if ($prewriter) {
        $res = $prewriter($obj, $srv, $id, $idold, $data);
        if ($res['code'])  $obj['msg'][] = $res['error'];
    }

    // Update object attributes
    if ($changed || empty($idold)) {
        // Either changed during update or creating a new record.
        if (is_array($writer)) {
            // As usual, array means LDAP
            // Empty $idold means a brand new record
            if (empty($idold))
                $res = uldap_entry_create($srv, $dn, $data);
            else
                $res = uldap_entry_update($srv, $dn, $data);
        } else {
            // As usual, string means a custom function
            $res = $writer($obj, $srv, $id, $idold, $data);
        }
        log_debug('writing to "%s" returns "%s"', $srv, $res['error']);
        // Note: code 82 == "no values to update"
        // code 53 == "Unwilling to perform" (FIXME!!!)
        if ($res['code'] && !($res['code'] == 82 || ($srv == 'ads' && $res['code'] == 53)))
            $obj['msg'][] = $res['error'];
    } else {
        // Not changed and not creating.
        log_debug('nothing to write to "%s"', $srv);
    }

    if ($obj['msg'])  return $obj['msg'];

    // DN can be handy for post-update routines
    uldap_set_dn($data, $dn);

    // Perform post-update operations
    foreach ($obj['attrs'] as $attr_name => &$at) {
        if (! isset($at['desc']['srv'][$srv]) || $at['desc']['readonly'])
            continue;
        $post_func = $at['desc']['ldap_write_final'];
        $ldap_attr = $at['desc']['srv'][$srv];
        $retval = $post_func($obj, $at, $srv, $data, $ldap_attr, nvl($at['val']));
        if ($retval)  $changed = $obj['changed'] = true;
    }

    return $obj['msg'];
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
    foreach ($array as $name => $val)
        $filter .= "(" . $name . "=" . obj_format_string($val, $obj) . ")";
    if (count($array) > 1)
        $filter = "(&"  . $filter . ")";
    return $filter;
}


//
// Substitute fields represented in the string as $(FIELD) by their values
//
function obj_format_string ($str, $obj = null, $override = null) {
    global $_obj_fmt;
    $_obj_fmt = array('obj' => $obj, 'ovr' => $override, 'err' => false);
    $res = preg_replace_callback('!\$\((\w+)\)!', '_obj_replace_match', $str);
    if ($_obj_fmt['err'])  $res = null;
    return $res;
}

$_obj_fmt = null;

function _obj_replace_match ($matches) {
    $name = $matches[1];
    global $_obj_fmt;
    if (isset($_obj_fmt['ovr'][$name]))
        return $_obj_fmt['ovr'][$name];
    if (empty($_obj_fmt['obj'])) {
        $_obj_fmt['err'] = true;
        return '';
    }
    if ($name == '_ID')
        $val = isset($_obj_fmt['obj']['id']) ? $_obj_fmt['obj']['id'] : '';
    else
        $val = get_attr($_obj_fmt['obj'], $name);
    if (empty($val))
        $_obj_fmt['err'] = true;
    return $val;
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
