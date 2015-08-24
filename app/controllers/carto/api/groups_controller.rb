# encoding: utf-8

require_relative 'paged_searcher'
require_dependency 'cartodb/errors'

module Carto
  module Api

    class GroupsController < ::Api::ApplicationController
      include PagedSearcher

      before_filter :load_organization
      before_filter :load_group, :only => [:destroy]

      def index
        page, per_page, order = page_per_page_order_params

        render_jsonp({
          groups: Carto::PagedModel.paged_association(@organization.groups, page, per_page, order).map { |g| Carto::Api::GroupPresenter.new(g).to_poro },
          total_entries: @organization.groups.count,
          total_org_entries: @organization.groups.count
        }, 200)
      end

      def create
        group = @organization.create_group(params['display_name'])
        render_jsonp(Carto::Api::GroupPresenter.new(group).to_poro, 200)
      rescue CartoDB::ModelAlreadyExistsError => e
        CartoDB.notify_debug('Group already exists', { params: params })
        render json: { errors: "A group with that data already exists" }, status: 409
      rescue => e
        CartoDB.notify_exception(e, { params: params , group: (group ? group : 'not created') })
        render json: { errors: e.message }, status: 500
      end

      def destroy
        @group.destroy_group_with_extension
        render json: {}, status: 200
      rescue => e
        CartoDB.notify_exception(e, { params: params , group: @group })
        render json: { errors: e.message }, status: 500
      end

      private

      def load_organization
        @organization = Carto::Organization.where(id: params['organization_id']).first
        render json: { errors: "Organization #{params['organization_id']} not found" }, status: 404 unless @organization
        render json: { errors: "Not organization owner" }, status: 400 unless @organization.owner_id == current_user.id
      end

      def load_group
        @group = @organization.groups.where(id: params['group_id']).first
        render json: { errors: "Group #{params['group_id']} not found" }, status: 404 unless @group
      end

    end
    
  end
end
