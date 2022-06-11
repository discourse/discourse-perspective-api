import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import I18n from "I18n";
import bootbox from "bootbox";

function initialize(api) {
  const siteSettings = api.container.lookup("site-settings:main");

  api.modifyClass("controller:composer", {
    pluginId: "discourse-perspective-api",
    _perspective_checked: null,

    perspectiveSave(force) {
      this.set("_perspective_checked", true);
      const result = this.save(force);

      // it's valid for save() to return null since we do that in core,
      // handle that here because sometimes we return a promise
      if (result != null && typeof result.then === "function") {
        result.finally(() => {
          this.set("disableSubmit", false);
          this.set("_perspective_checked", false);
        });
      } else {
        this.set("disableSubmit", false);
        this.set("_perspective_checked", false);
      }
    },

    save(force) {
      if (!this.siteSettings.perspective_enabled) {
        return this._super(...arguments);
      }

      // same validation code from controller
      if (this.disableSubmit && !this._perspective_checked) {
        return;
      }
      if (!this.showWarning) {
        this.set("model.isWarning", false);
      }

      const composer = this.model;
      if (composer.cantSubmitPost) {
        this.set("lastValidatedAt", Date.now());
        return;
      } else {
        // disable composer submit during perspective validation
        this.set("disableSubmit", true);
      }

      const bypassPM =
        !siteSettings.perspective_check_private_message &&
        this.get("topic.isPrivateMessage");
      const bypassSecuredCategories =
        !siteSettings.perspective_check_secured_categories &&
        this.get("model.category.read_restricted");
      const bypassCheck = bypassPM || bypassSecuredCategories;

      if (!bypassCheck && !this._perspective_checked) {
        return this.perspectiveCheckToxicity(composer, force);
      } else {
        this.set("disableSubmit", false);
        return this._super(force);
      }
    },

    perspectiveCheckToxicity(composer, force) {
      let concat = "";

      ["title", "raw", "reply"].forEach((item) => {
        const content = composer.get(item);
        if (content) {
          concat += `${content} `;
        }
      });

      concat.trim();

      return ajax("/perspective/post_toxicity", {
        type: "POST",
        data: { concat },
      })
        .then((response) => {
          if (response && response["score"] !== undefined) {
            const message = I18n.t("perspective.perspective_message");

            let buttons = [
              {
                label: I18n.t("perspective.composer_continue"),
                class: "btn perspective-continue-post",
                callback: () => this.perspectiveSave(force),
              },
              {
                label: I18n.t("perspective.composer_edit"),
                class: "btn-primary perspective-edit-post",
                callback: () => {
                  if (this.isDestroying || this.isDestroyed) {
                    return;
                  }

                  this.set("disableSubmit", false);
                },
              },
            ];
            bootbox.dialog(message, buttons);
            return;
          } else {
            this.perspectiveSave(force);
          }
        })
        .catch(() => {
          // fail silently
          this.perspectiveSave(force);
        });
    },
  });
}

export default {
  name: "discourse-perspective-api",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (
      siteSettings.perspective_enabled &&
      siteSettings.perspective_notify_posting_min_toxicity_enable
    ) {
      withPluginApi("0.8.17", initialize);
    }
  },
};
