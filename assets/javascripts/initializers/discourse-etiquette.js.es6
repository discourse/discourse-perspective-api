import { withPluginApi } from 'discourse/lib/plugin-api';

function initialize(api) {
  api.modifyClass('controller:composer', {
    save(force) {
      // same validataion code from controller
      if (this.get("disableSubmit")) return;
      if (!this.get('showWarning')) {
        this.set('model.isWarning', false);
      }
      const composer = this.get('model');
      if (composer.get('cantSubmitPost')) {
        this.set('lastValidatedAt', Date.now());
        return;
      }

      if (!force) {
        var concat = '';
        ['title', 'raw', 'reply'].forEach((item, _) => {
          const content = composer.get(item);
          if (content) {
            concat += `${content} `;
          }
        });
        concat.trim();
        composer.store.find('etiquette-message', { concat }).then(response => {
          if (response && response.content.length > 0) {
            const message = I18n.t("etiquette.etiquette_message");

            let buttons = [{
              "label": I18n.t("etiquette.composer_continue"),
              "class": "btn",
              callback: () => this.save(true)
            }, {
              "label": I18n.t("etiquette.composer_edit"),
              "class": "btn-primary"
            }];
            bootbox.dialog(message, buttons);
            return;
          } else {
            this._super(true);
          }
        }).catch(() => { // fail silently
          this._super(true);
        });
      } else {
        this._super(force);
      }

    }
  });
}

export default {
  name: 'discourse-etiquette',

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    if (siteSettings.etiquette_enabled) {
      withPluginApi('0.8.17', initialize);
    }
  }
}
