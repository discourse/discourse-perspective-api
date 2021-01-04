import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Perspective", function (needs) {
  needs.user();
  needs.settings({
    perspective_notify_posting_min_toxicity_enable: true,
  });

  test("Create a normal topic", async (assert) => {
    visit("/");
    click("#create-topic");

    await fillIn("#reply-title", "this is a normal title");
    await fillIn(".d-editor-input", "hello world! This is a normal topic");

    await click("#reply-control button.create");

    assert.ok(exists(".cooked"), "new topic created");
  });

  test("Create a toxic topic without api keys filled", async (assert) => {
    visit("/");
    click("#create-topic");

    await fillIn("#reply-title", "this is a normal title");
    await fillIn(
      ".d-editor-input",
      "Fuck. This is outrageous and dumb. Go to hell."
    );

    await click("#reply-control button.create");

    assert.ok(exists(".cooked"), "new topic created");
  });
});
