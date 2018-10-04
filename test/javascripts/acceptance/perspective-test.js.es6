import { acceptance } from "helpers/qunit-helpers";

acceptance('Discourse Perspective', {
  loggedIn: true,
  settings: {
    perspective_notify_posting_min_toxicity_enable: true
  }
});

test('Create a normal topic', (assert) => {
  visit("/");
  click('#create-topic');

  fillIn('#reply-title', 'this is a normal title');
  fillIn('.d-editor-input', "hello world! This is a normal topic");

  andThen(() => {
    click('#reply-control button.create');
  });

  andThen(() => {
    assert.ok(exists('.cooked'), "new topic created");
  });
});


test('Create a toxic topic without api keys filled', (assert) => {
  visit("/");
  click('#create-topic');

  fillIn('#reply-title', 'this is a normal title');
  fillIn('.d-editor-input', "Fuck. This is outrageous and dumb. Go to hell.");

  andThen(() => {
    click('#reply-control button.create');
  });

  andThen(() => {
    assert.ok(exists('.cooked'), "new topic created");
  });
});
