import { withPluginApi } from 'discourse/lib/plugin-api';
import { ajax } from 'discourse/lib/ajax';

function initialize(api) {
  api.modifyClass('controller:composer', {
    _etiquette_checked: null,

    etiquetteSave(force) {
      this.set('_etiquette_checked', true);
      this.save(force).finally(() => {
        this.set('_etiquette_checked', false);
      });
    },

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

      if (!this.get('_etiquette_checked')) {
        var concat = '';
        ['title', 'raw', 'reply'].forEach((item, _) => {
          const content = composer.get(item);
          if (content) {
            concat += `${content} `;
          }
        });
        concat.trim();
        ajax(`/etiquette/post_toxicity?concat=${concat}`).then(response => {
          if (response && response['score'] !== undefined) {
            const message = I18n.t("etiquette.etiquette_message");

            let buttons = [{
              "label": I18n.t("etiquette.composer_continue"),
              "class": "btn",
              callback: () => this.etiquetteSave(force)
            }, {
              "label": I18n.t("etiquette.composer_edit"),
              "class": "btn-primary"
            }];
            bootbox.dialog(message, buttons);
            return;
          } else {
            this.etiquetteSave(force);
          }
        }).catch(() => { // fail silently
          this.etiquetteSave(force);
        });
      } else {
        return this._super(force);
      }
    }
  });
}

export default {
  name: 'discourse-etiquette',

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    if (siteSettings.etiquette_enabled && !siteSettings.etiquette_backfill_posts) {
      withPluginApi('0.8.17', initialize);
    }
  }
}
