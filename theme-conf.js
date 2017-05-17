exports.conf = {
    dependencies: {
        themes: {
            'theme-open-ent': '../theme-open-ent/**/*',
            'entcore-css-lib': '../entcore-css-lib/**/*',
            'generic-icons': '../generic-icons/**/*'
        },
        widgets: {
            'notes': '../notes/**/*',
            'calendar-widget': '../calendar-widget/**/*'
        }
    },
    overriding: [
        { 
            parent: 'theme-open-ent', 
            child: 'ode',
            skins: ['default', 'dyslexic']
        }
    ]
};
