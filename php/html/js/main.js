// $Id$

var main = function() {
    Ext.get('no-js').hide();
    var panel = {
        title: _T('Manage Users'),
        html: 'Panel',
        region: 'center',
        margins: '2 2 2 2'
    };
    new Ext.Viewport({
        defaults: {
            bodyStyle: 'padding: 5px;',
        },
        layout: 'border',
        items: [
            panel
        ]
    });
};

Ext.onReady(main);

