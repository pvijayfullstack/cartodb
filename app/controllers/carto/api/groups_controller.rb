# encoding: utf-8

require_relative 'paged_searcher'
require_dependency 'cartodb/errors'

module Carto
  module Api

    class GroupsController < ::Api::ApplicationController
      include PagedSearcher

      ssl_required :index, :show, :create, :update, :destroy, :add_member, :remove_member unless Rails.env.development? || Rails.env.test?

      before_filter :load_organization
      before_filter :load_group, :only => [:show, :update, :destroy, :add_member, :remove_member]
      before_filter :org_owner_only, :only => [:create, :update, :destroy, :add_member, :remove_member]
      before_filter :org_users_only, :only => [:show, :index]
      before_filter :load_user, :only => [:add_member, :remove_member]

      def index
        page, per_page, order = page_per_page_order_params

        groups = @organization.groups
        groups = groups.where('name like ?', "%#{params[:q]}%") if params[:q]
        total_entries = groups.count

        groups = Carto::PagedModel.paged_association(groups, page, per_page, order)

        render_jsonp({
          groups: groups.map { |g| Carto::Api::GroupPresenter.new(g).to_poro },
          total_entries: total_entries,
          total_org_entries: @organization.groups.count
        }, 200)
      end

      def show
        render_jsonp(Carto::Api::GroupPresenter.new(@group).to_poro, 200)
      end

      def create
        group = @organization.create_group(params['display_name'])
        render_jsonp(Carto::Api::GroupPresenter.new(group).to_poro, 200)
      rescue CartoDB::ModelAlreadyExistsError => e
        CartoDB.notify_debug('Group already exists', { params: params })
        render json: { errors: "A group with that data already exists" }, status: 409
      rescue => e
        CartoDB.notify_exception(e, { params: params , group: (group ? group : 'not created') }, organization: @organization)
        render json: { errors: e.message }, status: 500
      end

      def update
        @group.rename_group_with_extension(params['display_name'])
        render_jsonp(Carto::Api::GroupPresenter.new(@group).to_poro, 200)
      rescue => e
        CartoDB.notify_exception(e, { params: params , group: @group })
        render json: { errors: e.message }, status: 500
      end

      def destroy
        @group.destroy_group_with_extension
        render json: {}, status: 200
      rescue => e
        CartoDB.notify_exception(e, { params: params , group: @group })
        render json: { errors: e.message }, status: 500
      end

      def add_member
        @group.add_member_with_extension(@user)
        render json: {}, status: 200
      rescue => e
        CartoDB.notify_exception(e, { params: params , group: @group, user: @user })
        render json: { errors: e.message }, status: 500
      end

      def remove_member
        @group.remove_member_with_extension(@user)
        render json: {}, status: 200
      rescue => e
        CartoDB.notify_exception(e, { params: params , group: @group, user: @user })
        render json: { errors: e.message }, status: 500
      end

      private

      def load_organization
        @organization = Carto::Organization.where(id: params['organization_id']).first
        render json: { errors: "Organization #{params['organization_id']} not found" }, status: 404 unless @organization
      end

      def org_users_only
        render json: { errors: "Not organization owner" }, status: 400 unless @organization.id == current_user.organization_id
      end

      def org_owner_only
        render json: { errors: "Not organization owner" }, status: 400 unless @organization.owner_id == current_user.id
      end

      def load_group
        @group = @organization.groups.where(id: params['group_id']).first
        render json: { errors: "Group #{params['group_id']} not found" }, status: 404 unless @group
      end

      def load_user
        @user = @organization.users.where(id: params['user_id']).first
        render json: { errors: "User #{params['user_id']} not found" }, status: 404 unless @user
      end

    end
    
  end
end
