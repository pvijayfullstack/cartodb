class Superadmin::OrganizationsController < Superadmin::SuperadminController
  respond_to :json

  ssl_required :show, :create, :update, :destroy, :index if Rails.env.production? || Rails.env.staging?
  before_filter :get_organization, only: [:update, :destroy, :show]

  layout 'application'

  def show
    respond_with(@organization.data(:extended => true))
  end

  def index
    @organizations = (params[:overquota].present? ? Organization.overquota(0.20) : Organization.all)

    respond_with(:superadmin, @organizations.map(&:data))
  end

  def create
    @organization = Organization.new
    @organization.set_fields_from_central(params[:organization], :create)
    if @organization.save && params[:organization][:owner_id].present? && @organization.owner.nil?
      # TODO: move this into a callback or a model method
      uo = CartoDB::UserOrganization.new(@organization.id, params[:organization][:owner_id])
      uo.promote_user_to_admin
    end
    respond_with(:superadmin, @organization)
  end

  def update
    @organization.set_fields_from_central(params[:organization], :update)
    @organization.save
    respond_with(:superadmin, @organization)
  end

  def destroy
    @organization.destroy_cascade
    respond_with(:superadmin, @organization)
  rescue => e
    Rollbar.report_message('Error deleting organization', 'error', { error: e.inspect, organization: self.inspect })
    respond_with({ errors: [ e.inspect ]})
  end

  private

  def get_organization
    @organization = Organization[params[:id]]
    raise RecordNotFound unless @organization
  end # get_organization

end
