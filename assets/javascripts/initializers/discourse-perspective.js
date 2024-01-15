import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import I18n from "I18n";

function initialize(api) {
  api.modifyClass("controller:composer", {
    pluginId: "discourse-perspective-api",

    _perspective_checked: null,
    dialog: service(),
    siteSettings: service(),

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
        !this.siteSettings.perspective_check_private_message &&
        this.get("topic.isPrivateMessage");
      const bypassSecuredCategories =
        !this.siteSettings.perspective_check_secured_categories &&
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
            this.dialog.confirm({
              confirmButtonLabel: "perspective.composer_edit",
              confirmButtonClass: "btn-primary perspective-edit-post",
              didConfirm: () => {
                if (this.isDestroying || this.isDestroyed) {
                  return;
                }

                this.set("disableSubmit", false);
              },
              message: I18n.t("perspective.perspective_message"),
              cancelButtonLabel: "perspective.composer_continue",
              cancelButtonClass: "perspective-continue-post",
              didCancel: () => this.perspectiveSave(force),
            });

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
    const siteSettings = container.lookup("service:site-settings");
    if (
      siteSettings.perspective_enabled &&
      siteSettings.perspective_notify_posting_min_toxicity_enable
    ) {
      withPluginApi("0.8.17", initialize);
    }
  },
};
