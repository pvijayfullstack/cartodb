# coding: utf-8
require_relative '../../models/map/presenter'

class Admin::TablesController < ApplicationController
  ssl_required :index, :show

  skip_before_filter :browser_is_html5_compliant?, :only => [:embed_map]
  before_filter      :login_required,              :only => [:index]
  after_filter       :update_user_last_activity,   :only => [:index, :show]

  def index
    @tables_count  = current_user.tables.count
  end

  # We only require login for index, so we must manage the security at this level.
  # we present different actions depending on if there is a user logged in or not.
  # if the user is not logged in, we redirect them to the public page
  def show
    if current_user.present?
      @table = Table.where(:id => params[:id], :user_id => current_user.id).first
      respond_to do |format|
        format.html
        download_formats @table, format
      end
    else
      redirect_to public_table_path(params[:id], :format => params[:format])
    end
  end

  def public
    @subdomain = CartoDB.extract_subdomain(request)
    @table     = Table.find_by_id_subdomain(@subdomain, params[:id])

    # Has quite strange checks to see if a user can access a public table
    if @table.blank? || @table.private? || ((current_user && current_user.id != @table.user_id) && @table.private?)
      render_403
    else
      @vizzjson = CartoDB::Map::Presenter.new(
        @table.map,
        { full: true },
        Cartodb.config
      )
      respond_to do |format|
        format.html { render 'public', layout: 'application_table_public' }
        download_formats @table, format
      end
    end
  end

  private
  def download_formats table, format
    format.sql  { send_data table.to_sql, send_data_conf(table, 'zip', 'zip') }
    format.kml  { send_data table.to_kml, send_data_conf(table, 'zip', 'kmz') }
    format.csv  { send_data table.to_csv, send_data_conf(table, 'zip', 'zip') }
    format.shp  { send_data table.to_shp, send_data_conf(table, 'octet-stream', 'zip') }
  end

  def send_data_conf table, type, ext
    { :type => "application/#{type}; charset=binary; header=present",
      :disposition => "attachment; filename=#{table.name}.#{ext}" }
  end

  def update_user_last_activity
    return true unless current_user.present?
    current_user.set_last_active_time
    current_user.set_last_ip_address request.remote_ip    
  end
end
