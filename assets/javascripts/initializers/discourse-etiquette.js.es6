import { withPluginApi } from 'discourse/lib/plugin-api';

function initialize(api) {
  api.modifyClass('component:composer-messages', {
    _lastEtiquetteCheck: null,
    _etiquetteMessage: null,

    // _findSimilar periodically runs, hook into this point
    _findSimilar() {
      this._super();

      var concat = '';
      const composer = this.get('composer');
      ['title', 'raw', 'reply'].forEach((item, _) => {
        const content = composer.get(item);
        if (content) {
          concat += `${content} `;
        }
      });
      concat.trim();
      if (concat === this._lastEtiquetteCheck) { return; }
      this._lastEtiquetteCheck = concat;

      const message = this._etiquetteMessage || composer.store.createRecord('composer-message', {
        id: 'etiquette_message',
        templateName: 'etiquette-message',
        extraClass: 'etiquette-message'
      });

      this._etiquetteMessage = message;

      // const etiquetteMessages = this.get('etiquetteMessages');
      composer.store.find('etiquette-message', { concat }).then(response => {
        // etiquetteMessages.clear();
        // etiquetteMessages.pushObjects(response);
        if (response) {
          message.set('etiquetteMessages', response);
          this.send('popup', message);
        } else if (message) {
          this.send('hideMessage', message);
        }
      });
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
