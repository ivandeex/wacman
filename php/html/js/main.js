// $Id$

/////////////////////////////////////////////////////////
// users
//

var user_obj = { changed: false };

var user_rec = Ext.data.Record.create([
    'uid',
    'cn',
    'dn'
    ]);

var user_store = new Ext.data.Store({
    url: 'user-list.php',
    autoLoad: true,
    reader: new Ext.data.JsonReader({
        root: 'rows',
        idProperty: 'uid'
    }, user_rec)
});

function user_add() {
    test_msg();
}

function user_delete() {
    test_msg();
}

function users_refresh() {
    user_store.reload();
}

function user_unselect() {
}

function user_change(user_sm) {
    Ext.Msg.alert('hihi','user change');
}

function user_load(user_sm, row_idx, rec) {
    Ext.Msg.alert('hihi','user load');
}

function user_save() {
}

function user_revert() {
}

/////////////////////////////////////////////////////////
// groups
//

var group_obj = { changed: false };

var group_rec = Ext.data.Record.create([
    'cn',
    'dn'
]);

var group_store = new Ext.data.Store({
    url: 'group-list.php',
    autoLoad: true,
    reader: new Ext.data.JsonReader({
        root: 'rows',
        idProperty: 'dn'
    }, group_rec)
});

function group_add() {
    test_msg();
}

function group_delete() {
    test_msg();
}

function groups_refresh() {
    group_store.reload();
}

function group_unselect() {
}

function group_change(user_sm) {
    Ext.Msg.alert('hihi','group change');
}

function group_load(user_sm, row_idx, rec) {
    Ext.Msg.alert('hihi','group load');
}

function group_save() {
}

function group_revert() {
}

/////////////////////////////////////////////////////////
// mailgroups
//

var mailgroup_rec = Ext.data.Record.create([
    'cn'
]);

var mailgroup_store = new Ext.data.Store({
    url: 'mailgroup-list.php',
    autoLoad: true,
    reader: new Ext.data.JsonReader({
        root: 'rows',
        idProperty: 'cn'
    }, mailgroup_rec)
});

function mailgroup_add() {
    test_msg();
}

function mailgroup_delete() {
    test_msg();
}

function mailgroups_refresh() {
    mailgroup_store.reload();
}

function mailgroup_unselect() {
}

function mailgroup_change(user_sm) {
    Ext.Msg.alert('hihi','mailgroup change');
}

function mailgroup_load(user_sm, row_idx, rec) {
    Ext.Msg.alert('hihi','group load');
}

function mailgroup_save() {
}

function mailgroup_revert() {
}

/////////////////////////////////////////////////////////
// Custom fields
//

Ext.form.FillerField = Ext.extend(Ext.form.TextField, {
});
Ext.reg('fillerfield', Ext.form.FillerField);

popup_functions = {
    yesno: 'create_yesno_chooser',
    gid: 'create_group_chooser',
    groups: 'create_user_groups_editor',
    users: 'create_group_users_editor',
    mgroups: 'create_user_mail_groups_editor',
    mailusers: 'create_mailgroup_users_editor'
};

Ext.form.PopupField = Ext.extend(Ext.form.TriggerField, {
    onTriggerClick: function() {
        func = popup_functions[this._desc.popup];
        Ext.Msg.alert('popup', func);
    }
});
Ext.reg('popupfield', Ext.form.PopupField);

/////////////////////////////////////////////////////////
// Translations (loaded dynamically)
//

function _T() {
	var args = arguments;
	var format = args[0];
	var message = translations && translations[format] ? translations[format] : format;
	for (i = 1; i < arguments.length; i++)
	    message = message.replace('%s', arguments[i]);
	return message;
};

function test_msg(e) {
    Ext.Msg.alert('hihi','hohoho');
}

/////////////////////////////////////////////////////////
// AJAX indicator
//

AjaxIndicator = Ext.extend(Ext.Button, {
    disabled: true,
    scale: 'medium',
    ajax_urls : new Array(),

    initComponent : function() {
        Ext.Ajax.on('beforerequest', function(conn, o) {
            if (this.ajax_urls.indexOf(o.url) == -1) {
                this.ajax_urls.push(o.url);
                this.showProgress();
            }
        }, this);

        Ext.Ajax.on('requestcomplete', function(conn, response, o) {
            this.ajax_urls.remove(o.url);
            if (this.ajax_urls.length <= 0)
                this.hideProgress();
        }, this);

        Ext.Ajax.on('requestexception', function(conn, response, o) {
            if (this.ajax_urls.length <= 0)
                this.hideProgress();
        }, this);

        this.hideProgress();
    },

    showProgress: function() { this.setIcon('images/throbber-24.gif'); },

    hideProgress: function() { this.setIcon('images/userman-32.png');  },
});

/////////////////////////////////////////////////////////
// GUI
//

function btn_id (cfg, op) {
    return 'btn_' + cfg.short_name + '_' + op;
}

function create_obj_tab (cfg) {

    var form_attrs = gui_attrs[cfg.obj_name];
    if (! form_attrs)
        return null;
    var desc_tabs = [];

    for (var i = 0; i < form_attrs.length; i++) {
        var tab_name = form_attrs[i][0];
        var tab_attrs = form_attrs[i][1];
        var fields = [];
        for (var j = 0; j < tab_attrs.length; j++) {
            var attr_name = tab_attrs[j];
            var desc = all_attrs[cfg.obj_name][attr_name];
            if (!desc) {
                Ext.Msg.alert(_T('attribute "%s" in object "%s" not defined', attr_name, cfg.obj_name));
                continue;
            }
            if (desc.disable)
                continue;
            var field = {
                xtype: 'textfield', //desc.popup ? 'popupfield' : 'fillerfield',
                name: desc.name,
                fieldLabel: desc.label,
                readonly: desc.readonly,
                //anchor: '-20',
                _desc: desc
            };
            if (desc.type == 'pass' && !config.show_password)
                field.inputType = 'password';
			//signal_connect(key_release_event => sub { mailgroup_entry_edited($at) });
			fields.push(field);
		}
		if (fields.length) {
            desc_tabs.push({
                title: _T(tab_name),
                layout: 'form',
                autoScroll: true,
                //autoHeight: true,
                bodyStyle: 'padding: 10px',
                labelWidth: 150,
                labelSeparator: '',
                items: fields
            });
        }
	}

    if (! desc_tabs.length)
        return null;

    var desc_form = {
        region: 'center',
        margins: '0 0 0 0',
        layout: 'fit',

        xtype: 'form',
        url: cfg.url,
        border: false,

        items: [{
            xtype: 'tabpanel',
            activeItem: 0,
            items: desc_tabs
        }],

        buttons: [{
            text: _T('Save'),
            icon: 'images/apply.png',
            scale: 'medium',
            handler: cfg.save_handler,
            id: btn_id(cfg, 'save')
        },{
            text: _T('Revert'),
            icon: 'images/revert.png',
            scale: 'medium',
            handler: cfg.revert_handler,
            id: btn_id(cfg, 'revert')
        }]
    };

    var desc_panel = {
        layout: 'border',
        region: 'center',
        items: [
            {region: 'north',
            margins: '5 5 5 5',
            xtype: 'label',
            text: '?',
            style: 'font-weight: bold; text-align: center',
            id: cfg.label_id
            }
            ,desc_form
        ]
    };

    var list_panel = {
        xtype: 'grid',
        store: cfg.store,
        colModel: new Ext.grid.ColumnModel({
            columns: cfg.list_columns
        }),
        selModel: new Ext.grid.RowSelectionModel({
            singleSelect: true,
            listeners: {
                rowdeselect: cfg.list_handler_change,
                rowselect: cfg.list_handler_select
            }
        }),
        region: 'west',
        split: true,
        collapsible: true,
        collapseMode: 'mini',
        width: cfg.list_width,
        minSize: 50
    };

    var obj_tab = {
        title: _T(cfg.tab_title),
        layout: 'border',
        items: [ list_panel, desc_panel ],
        bbar: {
            xtype: 'toolbar',
            items: [
            new AjaxIndicator(), ' ',
            {
                text: _T('Create'),
                icon: 'images/add.png',
                scale: 'medium',
                handler: user_add,
                id: btn_id(cfg, 'add')
            },{
                text: _T('Delete'),
                icon: 'images/delete.png',
                scale: 'medium',
                handler: user_delete,
                id: btn_id(cfg, 'delete')
            },{
                text: _T('Refresh'),
                icon: 'images/refresh.png',
                scale: 'medium',
                handler: users_refresh,
                id: btn_id(cfg, 'refresh')
            },'->',{
                text: _T('Exit'),
                icon: 'images/exit.png',
                scale: 'medium',
                handler: gui_exit
            }]
        }
    };

    return obj_tab;
}

/////////////////////////////////////////////////////////
// Main
//

function gui_exit() {
	if (user_obj.changed || group_obj.changed) {
		//my $resp = message_box('question', 'yes-no', _T('Exit and loose changes ?'));
		//return 1 if $resp ne 'yes';
		user_obj.changed = group_obj.changed = false;
	}
	user_unselect();
	group_unselect();
	mailgroup_unselect();
    Ext.Msg.alert('exit','Exit');
}

function main() {
    hide_preloader();
    var obj_tabs = [];

    var user_tab = create_obj_tab({
        obj_name: 'user',
        tab_title: ' Users ',
        store: user_store,
        url: 'user-write.php',
        label_id: 'title_user_name',
        save_handler: user_save,
        revert_handler: user_revert,
        list_width: 300,
        list_columns: [{
            header: _T('Identifier'),
            dataIndex: 'uid',
            sortable: true,
            width: 100,
        },{
            header: _T('Full name'),
            dataIndex: 'cn',
            sortable: true,
            width: 190
        }],
        list_handler_change: user_change,
        list_handler_select: user_load,
        handler_add: user_add,
        handler_delete: user_delete,
        handler_refresh: users_refresh
    });
    if (user_tab != null)
        obj_tabs.push(user_tab);

    var group_tab = create_obj_tab({
        obj_name: 'group',
        tab_title: ' Groups ',
        store: group_store,
        url: 'group-write.php',
        label_id: 'title_group_name',
        save_handler: group_save,
        revert_handler: group_revert,
        list_width: 150,
        list_columns: [{
            header: _T('Group name'),
            dataIndex: 'cn',
            sortable: true,
            width: 120
        }],
        list_handler_change: group_change,
        list_handler_select: group_load,
        handler_add: group_add,
        handler_delete: group_delete,
        handler_refresh: groups_refresh
    });
    if (group_tab != null)
        obj_tabs.push(group_tab);

    var mailgroup_tab = create_obj_tab({
        obj_name: 'mailgroup',
        tab_title: ' Mail groups ',
        store: mailgroup_store,
        url: 'mailgroup-write.php',
        label_id: 'title_group_name',
        save_handler: mailgroup_save,
        revert_handler: mailgroup_revert,
        list_width: 150,
        list_columns: [{
                header: _T('Mailgroup name'),
                dataIndex: 'cn',
                sortable: true,
                width: 140
        }],
        list_handler_change: mailgroup_change,
        list_handler_select: mailgroup_load,
        handler_add: mailgroup_add,
        handler_delete: mailgroup_delete,
        handler_refresh: mailgroups_refresh
    });
    if (mailgroup_tab != null)
        obj_tabs.push(mailgroup_tab);

    new Ext.Viewport({
        defaults: {
            bodyStyle: 'padding: 5px;',
        },
        layout: 'border',
        items: [{
            region: 'north',
            margins: '5 5 5 5',
            xtype: 'label',
            text: _T('Userman'),
            style: 'font-weight: bold; text-align: center'
        } , {
            region: 'center',
            margins: '0 0 0 0',
            xtype: 'tabpanel',
            activeTab: 0,
            items: obj_tabs
        }]
    });

	user_unselect();
	group_unselect();
	mailgroup_unselect();
};

/////////////////////////////////////////////////////////
// preloader
//

function hide_preloader() {
    var pre_mask = Ext.get('preloading-mask');
    var pre_box = Ext.get('preloading-box');
    //	Hide loading message			
    pre_box.fadeOut({ duration: 0.2, remove: true });
    //	Hide loading mask
    pre_mask.setOpacity(0.9);
    pre_mask.shift({
        xy: pre_box.getXY(),
        width: pre_box.getWidth(),
        height: pre_box.getHeight(),
        remove: true,
        duration: 0.7,
        opacity: 0.1,
        easing: 'bounceOut'
    });
}

Ext.onReady(main);

