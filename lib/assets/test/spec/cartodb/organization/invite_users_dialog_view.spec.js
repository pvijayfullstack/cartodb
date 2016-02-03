var cdb = require('cartodb.js-v3');
var InviteUsersDialogView = require('../../../../javascripts/cartodb/organization/invite_users/invite_users_dialog_view');


describe('organization/invite_users/invite_users_dialog_view', function() {

  beforeEach(function() {
    this.org = new cdb.admin.Organization({ id: 'pacoOrg' });
    this.orgUsers = new cdb.admin.Organization.Users(null, { organization: this.org });

    this.view = new InviteUsersDialogView({
      organization: this.org,
      organizationUsers: this.orgUsers
    });
    this.view.render();
  });

  it("should render properly", function() {
    expect(this.view._panes).toBeDefined();
    expect(this.view._panes.size()).toBe(3);
  });

  describe("form view", function() {

    beforeEach(function() {
      this.formView = this.view._panes.getPane('form');
      this.$form = this.view.$('.js-form');
    });

    it("should render tag input and welcome textarea", function() {
      expect(this.$form.find('.js-tagsList').length).toBe(1);
      expect(this.$form.find('.js-welcomeText').length).toBe(1);
    });

    it("should have submit button disabled", function() {
      spyOn(this.formView, 'trigger');
      var $button = this.$form.find('.js-submit');
      expect($button.hasClass('is-disabled')).toBeTruthy();
      $button.click();
      expect(this.formView.trigger).not.toHaveBeenCalled();
    });

    it("should enable submit button when welcome_text and any email is added", function() {
      var $button = this.$form.find('.js-submit');
      this.formView.model.set('users_emails', ["paco@gmail.com"]);
      this.formView._onChange();
      expect($button.hasClass('is-disabled')).toBeFalsy();
    });

    it("should send a trigger when form is submitted correctly", function() {
      var $button = this.$form.find('.js-submit');
      spyOn(this.formView, 'trigger');
      this.formView.model.set('users_emails', ["paco@gmail.com"]);
      $button.click();
      expect(this.formView.trigger).toHaveBeenCalled();
    });

  });

  describe("on save", function() {

    it("should show loading state when model is being saved", function() {
      this.view.model.sync = function() {};
      this.view.model.set('users_emails', ["paco@gmail.com"]);
      this.view._sendInvites();
      expect(this.view._panes.activeTab).toBe('loading');
    });

    it("should show close the dialog when model is properly saved", function() {
      this.view.model.sync = function(a,b,c) {
        c.success();
      };
      spyOn(this.view, 'close');
      this.view._sendInvites();
      expect(this.view.close).toHaveBeenCalled();
    });

    it("should show error state when model saved has any problem", function() {
      this.view.model.sync = function(a,b,c) {
        c.error();
      };
      this.view._sendInvites();
      expect(this.view._panes.activeTab).toBe('error');
    });

  });

});
