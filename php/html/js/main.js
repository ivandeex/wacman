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

function west_region (w, width) {
    w.region = 'west';
    w.split = true;
    w.collapsible = true;
    w.collapseMode = 'mini';
    w.width = width;
    w.minSize = 50;
    return w;
}

function center_region (w) {
    w.region = 'center';
    return w;
}

function create_obj_list (cfg) {
    var list = {
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
        })
    };
    return list;
}

function create_obj_desc (cfg) {

    var form_attrs = gui_attrs[cfg.obj_name];
    if (! form_attrs)
        return {};
    var tabs = [];

    for (i = 0; i < form_attrs.length; i++) {
        var tab_name = form_attrs[i][0];
        var tab_attrs = form_attrs[i][1];
        var items = [];
        var tab = {
            title: _T(tab_name),
            autoScroll: true,
            defaults: { anchor: '-20' },
            items: items
        };
        tabs.push(tab);
        for (j = 0; j < tab_attrs.length; j++) {
            var attr_name = tab_attrs[j];
            var desc = all_attrs[cfg.obj_name][attr_name];
            if (desc.disable)
                continue;
            if (!desc) {
                Ext.Msg.alert(_T('attribute "%s" in object "%s" not defined', attr_name, cfg.obj_name));
                continue;
            }
            var field = {
                xtype: desc.popup ? 'popupfield' : 'fillerfield',
                fieldLabel: desc.label,
                readonly: desc.readonly,
                _desc: desc
            };
            if (desc.type == 'pass' && !config.show_password)
                field.inputType = 'password';
			//signal_connect(key_release_event => sub { mailgroup_entry_edited($at) });
			items.push(field);
		}
	}

    var panel = {
        layout: 'border',
        items: [{
            region: 'north',
            margins: '5 5 5 5',
            xtype: 'label',
            text: '?',
            style: 'font-weight: bold; text-align: center',
            id: cfg.label_id
        },{
            region: 'center',
            margins: '0 0 0 0',
            xtype: 'form',
            layout: 'fit',
            url: cfg.url,
            frame: true,
            items: [{
                xtype: 'tabpanel',
                activeItem: 0,
                anchor: '100% 100%',
                deferredRender: false,
                defaults: {
                    layout: 'form',
                    labelWidth: 160,
                    defaultType: 'textfield',
                    bodyStyle: 'padding:5px',
                    hideMode: 'offsets'
                },
                items: tabs
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
		        id: btn_id(cfg, 'load')
            }]
        }]
    };

    return panel;
}

function create_obj_tab (cfg) {
    var tab = {
        title: _T(cfg.tab_title),
        layout: 'border',
        items: [
            west_region(create_obj_list(cfg), cfg.list_width),
            center_region(create_obj_desc(cfg))
        ],
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
    return tab;
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

    var user_tab = create_obj_tab({
        obj_name: 'user',
        tab_title: ' User ',
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

    var group_tab = create_obj_tab({
        obj_name: 'group',
        tab_title: ' Group ',
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

    var mailgroup_tab = create_obj_tab({
        obj_name: 'group',
        tab_title: ' Mail Group ',
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
            items: [ user_tab, group_tab, mailgroup_tab ]
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

