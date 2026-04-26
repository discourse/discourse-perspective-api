import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Toxic Post Score", function (needs) {
  needs.user();
  needs.settings({
    perspective_notify_posting_min_toxicity_enable: true,
    perspective_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.post("/perspective/post_toxicity", () => {
      return helper.response({ success: "OK", score: 0.99 });
    });
  });

  test("toxic topic, clicking edit keeps the composer open", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn("#reply-title", "this is a normal title");
    await fillIn(".d-editor-input", "everyone is a doo-doo head!");

    await click("#reply-control button.create");
    await click(".perspective-edit-post");

    assert.strictEqual(currentURL(), "/", "stays on the homepage");
    assert.dom("#reply-control").hasClass("open", "composer is still open");
  });

  test("toxic topic, clicking continue submits the post", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn("#reply-title", "this is a normal title");
    await fillIn(".d-editor-input", "everyone is a doo-doo head!");

    await click("#reply-control button.create");
    await click(".perspective-continue-post");

    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280",
      "navigates to the new topic"
    );
    assert.dom("#reply-control").hasClass("closed", "composer is closed");
  });
});

acceptance("No Post Score", function (needs) {
  needs.user();
  needs.settings({
    perspective_notify_posting_min_toxicity_enable: true,
    perspective_enabled: true,
  });

  needs.pretender((server, helper) => {
    server.post("/perspective/post_toxicity", () => {
      return helper.response({ success: "OK" });
    });
  });

  test("submits the topic without showing the dialog", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn("#reply-title", "this is a normal title");
    await fillIn(".d-editor-input", "everyone is a doo-doo head!");

    await click("#reply-control button.create");

    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280",
      "navigates to the new topic"
    );
    assert.dom("#reply-control").hasClass("closed", "composer is closed");
  });
});

acceptance("Form Template Category", function (needs) {
  needs.user();
  needs.settings({
    perspective_notify_posting_min_toxicity_enable: true,
    perspective_enabled: true,
    enable_form_templates: true,
  });

  const formTemplate = {
    id: 1,
    template: `
      - type: input
        id: full-name
        attributes:
          label: "Name"
    `,
  };

  needs.site({
    categories: [{ id: 1, form_template_ids: [1] }],
  });

  needs.pretender((server, helper) => {
    server.post("/perspective/post_toxicity", () => {
      return helper.response({ success: "OK", score: 0.99 });
    });
    server.get("/form-templates/1.json", () =>
      helper.response({ form_template: formTemplate })
    );
  });

  test("form template post with toxic score, clicking continue submits", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await fillIn("#reply-title", "this is a normal title");
    await fillIn(
      ".form-template-field__input[name='full-name']",
      "doo-doo head"
    );

    await click("#reply-control button.create");
    await click(".perspective-continue-post");

    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280",
      "navigates to the new topic"
    );
    assert.dom("#reply-control").hasClass("closed", "composer is closed");
  });
});
