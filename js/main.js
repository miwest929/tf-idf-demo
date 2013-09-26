App = Ember.Application.create({
  LOG_TRANSITIONS: true
});

App.Document = Ember.Object.extend();
var documents = Em.A();

App.DocumentsRoute = Ember.Route.extend({
  totalCount: 0,
  model: function() {
    return documents;
  }
});

App.Router.map(function() {
  this.resource('documents', function() {
    this.resource('document', {path: ':document_id'});
  });
});

App.DocumentRoute = Ember.Route.extend({
  model: function(params) {
    return this.get('store').find('document', params.document_id);
  }
});

App.DocumentsView = Ember.View.extend({
  actions: {
    add_doc: function() {
      this.set('templateName', 'add_doc');
      console.log("Adding new document!");
    }
  }
});

App.IndexRoute = Ember.Route.extend({
  redirect: function() {
    this.transitionTo('documents');
  }
});

$.getJSON("http://localhost:9494/documents").then(
  function(response) {
    response.documents.forEach(function(doc) {
      documents.pushObject(App.Document.create(doc));
    });
  }
);
