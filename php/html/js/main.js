  Ext.onReady(function(){
      Ext.get('show-btn').on('click', function(){
          var win;
          win = new Ext.Window({
                applyTo:'hello-win',
                layout:'fit',
                width:500,
                height:300,
                closeAction:'hide',
                plain: true,

                items: new Ext.TabPanel({
                    applyTo: 'hello-tabs',
                    autoTabs:true,
                    activeTab:0,
                    deferredRender:false,
                    border:false
                }),

                buttons: [{
                    text:'Submit',
                    disabled:true
                },{
                    text: 'Close',
                    handler: function(){
                        win.hide();
                    }
                }]
            });
          win.show(this);
      });
  });

