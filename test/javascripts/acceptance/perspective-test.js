import { click, fillIn, visit } from "@ember/test-helpers";
import { skip, test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance(
  "Discourse Perspective | Enabled | Toxic Post Score",
  function (needs) {
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

    skip("Create a toxic topic and click edit before continuing", async function (assert) {
      await visit("/");
      await click("#create-topic");
      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(2);

      await fillIn("#reply-title", "this is a normal title");
      await fillIn(".d-editor-input", "everyone is a doo-doo head!");

      await click("#reply-control button.create");

      await click(".perspective-edit-post");
      assert.notOk(
        exists(".cooked"),
        "new topic was not created, composer is still open"
      );
    });

    skip("Create a toxic topic and click continue with post creation", async function (assert) {
      await visit("/");
      await click("#create-topic");
      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(2);

      await fillIn("#reply-title", "this is a normal title");
      await fillIn(".d-editor-input", "everyone is a doo-doo head!");

      await click("#reply-control button.create");

      await click(".perspective-continue-post");
      assert.ok(exists(".cooked"), "new topic created");
    });
  }
);

acceptance("Discourse Perspective | Enabled | No Post Score", function (needs) {
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

  test("Create a topic without issues", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await fillIn("#reply-title", "this is a normal title");
    await fillIn(".d-editor-input", "everyone is a doo-doo head!");

    await click("#reply-control button.create");
    assert.ok(exists(".cooked"), "new topic created");
  });
});
