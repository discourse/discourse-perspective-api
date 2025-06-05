import RouteTemplate from "ember-route-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <a href {{@controller.closeMessage}} class="close">{{icon "close"}}</a>

    <h3>{{i18n "perspective.perspective_messages"}}</h3>

    <div class="messages">
      <p>{{i18n "perspective.perspective_warning"}}</p>
    </div>
  </template>
);
