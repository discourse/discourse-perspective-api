import { withPluginApi } from 'discourse/lib/plugin-api';

function initialize(api) {
  api.modifyClass('component:composer-messages', {
    _lastEtiquetteCheck: null,
    _etiquetteMessage: null,

    // _findSimilar periodically runs, hook into this point
    _findSimilar() {
      this._super();

      const composer = this.get('composer');
      const title = composer.get('title');
      const raw = composer.get('raw');
      const concat = `${title} ${raw}`;
      if (concat === this._lastEtiquetteCheck) { return; }
      this._lastEtiquetteCheck = concat;

      const message = this._etiquetteMessage || composer.store.createRecord('composer-message', {
        id: 'etiquette_message',
        templateName: 'etiquette-message',
        extraClass: 'etiquette-message'
      });
      console.log(message);

      this._etiquetteMessage = message;

      composer.store.find('etiquette-message', { concat }).then(response => {
        if (response) {
          message.set(response);
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
    console.log(container);
    const siteSettings = container.lookup('site-settings:main');
    if (siteSettings.etiquette_enabled) {
      withPluginApi('0.8.17', initialize);
    }
  }
}
